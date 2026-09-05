# Merged into: flake.modules.nixos.hardware-petunia
# Configures: Ryzen 5600X boot modules, microcode, sound, and network interfaces.
# Imported by: hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.hardware-petunia = _: {
    # Core Hardware Support for Ryzen Desktop (AM4/X570)
    # Optimized for Ryzen 5 5600X (Zen 3) + Gigabyte X570 AORUS MASTER

    boot = {
      initrd.availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];

      # it87 is often needed for the ITE IT8688E Super I/O on Gigabyte boards
      kernelModules = [
        "kvm-amd"
        "k10temp"
        "it87"
      ];

      # CPPC (Collaborative Processor Performance Control) Optimization
      # In 6.12+, amd_pstate=active is the preferred modern mode for Zen 3.
      # This uses the EPP (Energy Performance Preference) algorithm.
      kernelParams = [
        "amd_pstate=active"
        "pcie_aspm=off" # Recommended for some X570 boards to avoid DPC latency
      ];
    };

    # Microcode for security and stability
    hardware.cpu.amd.updateMicrocode = true;

    # Bluetooth for Intel AX200 (Intel Wi-Fi 6 AX200)
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    # Sound settings for ALC1220-VB
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    # Realtek 2.5GbE (RTL8125) and Intel 1GbE (I211) stability
    # r8169 is generally good, but we can ensure networking is stable.
    networking.interfaces.enp8s0.useDHCP = true; # 2.5G
    networking.interfaces.enp7s0.useDHCP = true; # 1G

    # SSD Longevity and performance
    services.fstrim.enable = true;
  };
}
