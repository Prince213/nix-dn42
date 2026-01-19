{
  config,
  lib,
  ...
}:
let
  cfg = config.networking.dn42;
in
{
  options.networking.dn42 = {
    enable = lib.mkEnableOption "DN42";
  };

  config = lib.mkIf cfg.enable {
  };
}
