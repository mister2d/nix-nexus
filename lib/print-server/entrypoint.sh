#!/bin/sh
# entrypoint.sh - print-server container PID 1.
#
# Persistent state (Nomad CSI mount) lives under /data. On every start this
# script re-seeds the CUPS config from the read-only image (so the shipped
# cupsd.conf/cups-files.conf always win) while leaving printers.conf, PPDs,
# and TLS keys under /data/etc-cups untouched across restarts. It then starts
# cupsd in the foreground and, in the background, keeps the single shared
# queue provisioned even while the backing printer is powered off.
set -eu

: "${PRINTER_NAME:=hp-m283fdw}"
: "${PRINTER_URI:=ipp://10.0.5.10/ipp/print}"
: "${PRINTER_INFO:=HP Color LaserJet Pro MFP M283fdw}"
: "${ADMIN_SUBNET:=10.0.1.0/24}"

DATA_DIR=/data
ETC_CUPS="$DATA_DIR/etc-cups"
SPOOL_DIR="$DATA_DIR/spool"
CACHE_DIR=/var/cache/cups
STATE_DIR=/run/cups

CUPSD_CONF_TEMPLATE=/etc/print-server/cupsd.conf
CUPS_FILES_CONF_SRC=/etc/print-server/cups-files.conf

# Talk to cupsd over its local Unix domain socket, not TCP :631, so local
# lpadmin/lpstat do not depend on the network listener.
export CUPS_SERVER="$STATE_DIR/cups.sock"

# Private state: spool, TLS keys, generated config.
umask 077
mkdir -p "$ETC_CUPS" "$ETC_CUPS/ssl" "$SPOOL_DIR/tmp"

# Shared/ephemeral state: cache and the runtime socket directory.
umask 022
mkdir -p "$CACHE_DIR" "$STATE_DIR"

# Refresh the generated config from the image on every start. printers.conf,
# ppd/, and ssl/ under $ETC_CUPS are left alone; cupsd owns those.
sed "s|__ADMIN_SUBNET__|$ADMIN_SUBNET|g" "$CUPSD_CONF_TEMPLATE" >"$ETC_CUPS/cupsd.conf"
cp "$CUPS_FILES_CONF_SRC" "$ETC_CUPS/cups-files.conf"

cupsd -f -c "$ETC_CUPS/cupsd.conf" -s "$ETC_CUPS/cups-files.conf" &
cupsd_pid=$!

term_handler() {
  echo "entrypoint: caught termination signal, stopping cupsd (pid $cupsd_pid)" >&2
  kill -TERM "$cupsd_pid" 2>/dev/null || true
  wait "$cupsd_pid" 2>/dev/null || true
  exit 0
}
trap term_handler TERM INT

# Keep the single shared queue provisioned. The backing printer
# (ipp://10.0.5.10) is often powered off, so lpadmin failures are expected
# and retried with exponential backoff. Once the queue exists, recheck at
# the max interval in case it is later deleted.
provision_loop() {
  delay=30
  max_delay=300
  while true; do
    if lpstat -p "$PRINTER_NAME" >/dev/null 2>&1; then
      delay=30
      sleep "$max_delay"
      continue
    fi

    echo "entrypoint: provisioning queue '$PRINTER_NAME' -> $PRINTER_URI" >&2
    if lpadmin -p "$PRINTER_NAME" -D "$PRINTER_INFO" -v "$PRINTER_URI" -m everywhere -E \
      -o printer-is-shared=true -o printer-error-policy=retry-job; then
      echo "entrypoint: queue '$PRINTER_NAME' provisioned" >&2
      delay=30
      continue
    fi

    echo "entrypoint: lpadmin failed for '$PRINTER_NAME', retrying in ${delay}s" >&2
    sleep "$delay"
    delay=$((delay * 2))
    if [ "$delay" -gt "$max_delay" ]; then
      delay=$max_delay
    fi
  done
}

# Wait for the scheduler socket before the first provisioning check, so an
# early lpstat/lpadmin does not race cupsd's startup.
wait_for_cupsd() {
  i=0
  until [ "$(lpstat -r 2>/dev/null)" = "scheduler is running" ]; do
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then
      echo "entrypoint: cupsd not answering after 60s, provisioning anyway" >&2
      return 0
    fi
    sleep 1
  done
}

{
  wait_for_cupsd
  provision_loop
} &

wait "$cupsd_pid"
