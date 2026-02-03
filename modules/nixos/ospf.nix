{ config, lib, ... }:
let
  cfg = config.networking.dn42.ospf;
in
{
  options.networking.dn42.ospf = {
    enable = lib.mkEnableOption "OSPF";
  };

  config = lib.mkIf cfg.enable {
  };
}
