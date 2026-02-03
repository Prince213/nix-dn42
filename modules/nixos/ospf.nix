{ config, lib, ... }:
let
  cfg = config.networking.dn42.ospf;
  interfaces = lib.filterAttrs (_: { enable, ... }: enable) cfg.interfaces;
in
{
  options.networking.dn42.ospf = {
    enable = lib.mkEnableOption "OSPF";
    interfaces = lib.mkOption {
      description = "Interfaces to use for OSPF.";
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              enable = lib.mkEnableOption "enable the interface" // {
                default = true;
              };
              name = lib.mkOption {
                type = lib.types.str;
                description = "Name of the interface.";
                default = name;
              };
            };
          }
        )
      );
    };
  };

  config = lib.mkIf cfg.enable {
    services.bird.config = ''
      protocol ospf v2 ospfv2 {
        ipv4 {
          export where source ~ [ RTS_DEVICE, RTS_OSPF, RTS_BGP ];
        };
        area 0 {
          ${lib.concatMapAttrsStringSep "\n" (
            _:
            { name, ... }:
            ''
              interface "${name}" {
                type ptp;
              };
            ''
          ) interfaces}
        };
      }

      protocol ospf v3 ospfv3 {
        rfc5838 off;
        ipv6 {
          export where source ~ [ RTS_DEVICE, RTS_OSPF, RTS_BGP ];
        };
        area 0 {
          interface "dn42-dummy" { stub yes; };

          ${lib.concatMapAttrsStringSep "\n" (
            _:
            { name, ... }:
            ''
              interface "${name}" {
                type ptp;
              };
            ''
          ) interfaces}
        };
      }
    '';
  };
}
