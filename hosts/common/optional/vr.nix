{ pkgs, config, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      libva
      vaapiVdpau
      libgpg-error
    ];
  };
  boot.kernelModules = [
    "v4l2loopback"
    "uinput"
  ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.extraModprobeConfig = ''
    options v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
  '';
  environment.systemPackages = with pkgs; [ v4l-utils ];
}
