{ config, lib, ... }:
let
  cfg = config.networking.dn42.babel;
in
{
  options.networking.dn42.babel = {
    enable = lib.mkEnableOption "Babel";
  };

  config = lib.mkIf cfg.enable {
  };
}
