# gpu-profile: switch the R9700 power profile on petunia.
#
#   gpu-profile status
#   gpu-profile default                     declared profile (LACT: 230 W cap, no offset)
#   gpu-profile stock                       stock cap, no voltage offset, LACT stopped
#   gpu-profile custom --cap W --offset mV  guarded values written to sysfs, LACT stopped
#                      [--over-stock] [--force]
#
# default hands control back to lactd. stock and custom stop lactd (its
# cleanup resets the GPUs first) and write sysfs directly, so nothing
# re-applies over them; they last until `gpu-profile default` or a reboot.

readonly VENDOR=0x1002
readonly DEVICE=0x7551
readonly OFFSET_WARN=-80
readonly OFFSET_SOFT_FLOOR=-100
readonly OFFSET_UNCAPPED_FLOOR=-50

die() { echo "gpu-profile: $*" >&2; exit 1; }
warn() { echo "gpu-profile: warning: $*" >&2; }

usage() { echo "usage: gpu-profile {status|default|stock|custom --cap W --offset mV [--over-stock] [--force]}"; }

cards=()
for d in /sys/class/drm/card[0-9]*/device; do
  c=${d%/device}
  [[ ${c##*/} == *-* ]] && continue
  [[ -r $d/vendor && -r $d/device ]] || continue
  [[ $(<"$d/vendor") == "$VENDOR" && $(<"$d/device") == "$DEVICE" ]] && cards+=("$d")
done
((${#cards[@]} > 0)) || die "no R9700 found"

hwmon_of() { local h; for h in "$1"/hwmon/hwmon*; do echo "$h"; return; done; }
od_offset() { awk '/^OD_VDDGFX_OFFSET:/{getline; gsub(/mV/, ""); print $1}' "$1/pp_od_clk_voltage"; }
od_floor() { awk '/^VDDGFX_OFFSET:/{gsub(/mv/, "", $2); print $2}' "$1/pp_od_clk_voltage"; }
watts() { echo $(($(<"$1") / 1000000)); }

cmd_status() {
  local d h
  for d in "${cards[@]}"; do
    h=$(hwmon_of "$d")
    printf '%s  cap %sW (min %s, default %s, max %s)  offset %smV  level %s\n' \
      "${d%/device}" "$(watts "$h/power1_cap")" "$(watts "$h/power1_cap_min")" \
      "$(watts "$h/power1_cap_default")" "$(watts "$h/power1_cap_max")" \
      "$(od_offset "$d")" "$(<"$d/power_dpm_force_performance_level")"
  done
  echo "lactd: $(systemctl is-active lactd || true)"
}

cmd_default() {
  systemctl restart lactd
  sleep 7  # lactd applies the config after its apply_settings_timer
  cmd_status
}

cmd_stock() {
  local d h
  systemctl stop lactd
  for d in "${cards[@]}"; do
    h=$(hwmon_of "$d")
    echo auto >"$d/power_dpm_force_performance_level"
    echo r >"$d/pp_od_clk_voltage"
    echo c >"$d/pp_od_clk_voltage"
    echo "$(<"$h/power1_cap_default")" >"$h/power1_cap"
  done
  cmd_status
  echo "lactd stopped; 'gpu-profile default' restores the declared profile."
}

cmd_custom() {
  local cap="" offset="" force=0 over=0
  while (($#)); do
    case $1 in
      --cap) cap=${2:?--cap needs watts}; shift 2 ;;
      --offset) offset=${2:?--offset needs mV}; shift 2 ;;
      --force) force=1; shift ;;
      --over-stock) over=1; shift ;;
      *) die "unknown option $1" ;;
    esac
  done
  [[ $cap =~ ^[0-9]+$ ]] || die "--cap must be whole watts"
  [[ $offset =~ ^-?[0-9]+$ ]] || die "--offset must be whole mV (0 or negative)"
  ((offset <= 0)) || die "positive voltage offsets are refused"

  local d h min max def floor
  for d in "${cards[@]}"; do
    h=$(hwmon_of "$d")
    min=$(watts "$h/power1_cap_min"); max=$(watts "$h/power1_cap_max"); def=$(watts "$h/power1_cap_default")
    floor=$(od_floor "$d")
    ((cap >= min && cap <= max)) || die "${d%/device}: cap ${cap}W outside driver range ${min}-${max}W"
    ((cap <= def || over)) || die "cap above stock ${def}W needs --over-stock"
    ((cap <= def)) || warn "cap ${cap}W is above stock; budget PSU headroom for both cards"
    ((offset >= floor)) || die "${d%/device}: offset ${offset}mV outside card range ${floor}-0mV"
    ((offset >= OFFSET_SOFT_FLOOR || force)) || die "offset below ${OFFSET_SOFT_FLOOR}mV needs --force"
    ((offset >= OFFSET_WARN)) || warn "offset ${offset}mV is deeper than commonly reported stable values"
    ((offset >= OFFSET_UNCAPPED_FLOOR || cap < def)) || die "offset below ${OFFSET_UNCAPPED_FLOOR}mV needs a cap under stock ${def}W"
  done

  local dmesg_before; dmesg_before=$(dmesg | grep -c 'amdgpu.*\(timeout\|reset\)' || true)
  systemctl stop lactd
  for d in "${cards[@]}"; do
    h=$(hwmon_of "$d")
    echo manual >"$d/power_dpm_force_performance_level"
    echo "vo $offset" >"$d/pp_od_clk_voltage"
    echo c >"$d/pp_od_clk_voltage"
    echo $((cap * 1000000)) >"$h/power1_cap"
    [[ $(od_offset "$d") == "$offset" ]] || die "${d%/device}: offset readback $(od_offset "$d") != $offset"
    [[ $(watts "$h/power1_cap") == "$cap" ]] || die "${d%/device}: cap readback mismatch"
  done
  cmd_status
  echo "lactd stopped; 'gpu-profile default' restores the declared profile."
  echo "Test under sustained load; amdgpu timeout/reset lines in dmesg at start: $dmesg_before"
}

case ${1:-status} in
  status) cmd_status ;;
  default | stock | custom)
    ((EUID == 0)) || exec /run/wrappers/bin/sudo -- "$0" "$@"
    sub=$1; shift
    "cmd_$sub" "$@"
    ;;
  *) usage; exit 2 ;;
esac
