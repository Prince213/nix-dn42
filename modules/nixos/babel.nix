{ config, lib, ... }:
let
  cfg = config.networking.dn42.babel;
in
{
  options.networking.dn42.babel = {
    enable = lib.mkEnableOption "Babel";
  };

  config = lib.mkIf cfg.enable {
    services.bird.config = ''
      protocol direct {
        ipv4;
        ipv6;

        interface "dn42-dummy";
      }
    '';
  };
}
