{ config, lib, ... }:
let
  cfg = config.networking.dn42.babel;
in
{
  options.networking.dn42.babel = {
    enable = lib.mkEnableOption "Babel";
    interface = lib.mkOption {
      type = lib.types.str;
      description = "Interface to use for Babel.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 6696;
      description = "Port to use for Babel.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.bird.config = ''
      protocol direct {
        ipv4;
        ipv6;

        interface "dn42-dummy";
      }

      protocol babel {
        ipv4 {
          export where (source = RTS_DEVICE) || (source = RTS_BABEL);
        };
        ipv6 {
          export where (source = RTS_DEVICE) || (source = RTS_BABEL);
        };

        interface "${cfg.interface}" {
          type tunnel;
          port ${toString cfg.port};
          extended next hop on;
        };
      }
    '';
  };
}
