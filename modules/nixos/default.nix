{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.networking.dn42;

  registry_wizard = lib.getExe pkgs.dn42_registry_wizard;
  roa = pkgs.runCommand "roa" { } ''
    mkdir -p $out
    ${registry_wizard} ${cfg.roa.registry} roa v4 >$out/dn42_roa4.conf
    ${registry_wizard} ${cfg.roa.registry} roa v6 >$out/dn42_roa6.conf
  '';
in
{
  options.networking.dn42 = {
    enable = lib.mkEnableOption "DN42";
    asn = lib.mkOption {
      type = lib.types.ints.u32;
      description = "The ASN to use for DN42.";
    };
    ipv4 = {
      address = lib.mkOption {
        type = lib.types.str;
        description = "The IPv4 source address.";
      };
      pool = lib.mkOption {
        type = lib.types.str;
        description = "The IPv4 address space.";
      };
    };
    ipv6 = {
      address = lib.mkOption {
        type = lib.types.str;
        description = "The IPv6 source address.";
      };
      pool = lib.mkOption {
        type = lib.types.str;
        description = "The IPv6 address space.";
      };
    };
    bird = {
      routerId = lib.mkOption {
        type = lib.types.str;
        default = cfg.ipv4.address;
        description = "The router ID to use for BIRD.";
      };
    };
    roa = {
      enable = lib.mkEnableOption "ROA checks";
      registry = lib.mkOption {
        type = lib.types.path;
        description = "Path to the DN42 registry.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.bird = {
      enable = true;
      config = lib.mkBefore ''
        router id ${cfg.bird.routerId};

        protocol device {
          scan time 10;
        }

        protocol kernel {
          ipv4 {
            import none;
            export filter {
              if source = RTS_STATIC then reject;
              krt_prefsrc = ${cfg.ipv4.address};
              accept;
            };
          };
        }

        protocol kernel {
          ipv6 {
            import none;
            export filter {
              if source = RTS_STATIC then reject;
              krt_prefsrc = ${cfg.ipv6.address};
              accept;
            };
          };
        }

        protocol static {
          route ${cfg.ipv4.pool} unreachable;
          ipv4;
        }

        protocol static {
          route ${cfg.ipv6.pool} unreachable;
          ipv6;
        }

        ${lib.optionalString cfg.roa.enable ''
          roa4 table dn42_roa4;
          roa6 table dn42_roa6;

          protocol static {
            roa4 { table dn42_roa4; };
            include "${roa}/dn42_roa4.conf";
          }

          protocol static {
            roa6 { table dn42_roa6; };
            include "${roa}/dn42_roa6.conf";
          }
        ''}

        template bgp dn42_peer {
          local as ${toString cfg.asn};

          ipv4 {
            extended next hop on;

            import filter {
              ${lib.optionalString cfg.roa.enable ''
                if roa_check(dn42_roa4) != ROA_VALID then reject;
              ''}
              accept;
            };

            export filter {
              accept;
            };
          };

          ipv6 {
            import filter {
              ${lib.optionalString cfg.roa.enable ''
                if roa_check(dn42_roa6) != ROA_VALID then reject;
              ''}
              accept;
            };

            export filter {
              accept;
            };
          };
        }
      '';
    };

    systemd.network = {
      enable = true;
      netdevs = {
        "10-dn42-dummy" = {
          netdevConfig = {
            Name = "dn42-dummy";
            Kind = "dummy";
          };
        };
      };
      networks = {
        "10-dn42-dummy" = {
          name = "dn42-dummy";
          address = [
            "${cfg.ipv4.address}/32"
            "${cfg.ipv6.address}/128"
          ];
        };
      };
    };
  };
}
