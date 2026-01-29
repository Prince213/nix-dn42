{ config, lib, ... }:
let
  cfg = config.networking.dn42.babel;
in
{
  options.networking.dn42.babel = {
    enable = lib.mkEnableOption "Babel";
    interfaces = lib.mkOption {
      description = "Interfaces to use for Babel.";
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Name of the interface.";
                default = name;
              };
              port = lib.mkOption {
                type = lib.types.port;
                default = 6696;
                description = "Port to use for Babel.";
              };
              openFirewall = lib.mkEnableOption null // {
                description = "Whether to open port in the firewall.";
              };
            };
          }
        )
      );
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = lib.concatMap (
      { port, openFirewall, ... }: lib.optional openFirewall port
    ) (lib.attrValues cfg.interfaces);

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

        ${lib.concatMapAttrsStringSep "\n" (
          _:
          { name, port }:
          ''
            interface "${name}" {
              type tunnel;
              port ${toString port};
              extended next hop on;
            };
          ''
        ) cfg.interfaces}
      }
    '';
  };
}
