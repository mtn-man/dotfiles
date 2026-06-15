{ config, lib, pkgs, ... }:

{
  # Intel UHD Graphics — 10th gen Comet Lake uses the iHD (intel-media-driver) path.
  hardware.graphics = {
    enable        = true;
    extraPackages = with pkgs; [
      intel-media-driver    # VA-API: iHD for Gen 8+
      intel-compute-runtime # OpenCL
    ];
  };

  # Force iHD so VA-API tools (mpv, ffmpeg) pick the right driver.
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # WiFi firmware (Intel AX200) and other proprietary blobs
  hardware.enableRedistributableFirmware = true;

  # TLP — ThinkPad-tuned power management.
  # TLP and power-profiles-daemon are mutually exclusive; PPD is disabled below.
  services.tlp = {
    enable   = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC  = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # Battery charge thresholds — match Fedora bootstrap values.
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0  = 80;

      RUNTIME_PM_ON_BAT = "auto";
      PCIE_ASPM_ON_BAT  = "powersupersave";
    };
  };
  services.power-profiles-daemon.enable = false;

  # ThinkPad ACPI module for thermal/fan control
  boot.kernelModules = [ "thinkpad_acpi" ];

  zramSwap.enable = true;

  services.upower.enable = true;

  # Fingerprint reader (comment out if unused)
  services.fprintd.enable = true;

  # NOTE: throttled (Intel thermal throttling fix for 10th gen T14) is not in
  # nixpkgs. If thermal throttling is observed under load, consider adding a
  # flake overlay or tracking https://github.com/NixOS/nixpkgs/issues/... for
  # an eventual package, or using a systemd unit that runs throttled directly.
}
