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

        template bgp dn42_peer {
          local as ${toString cfg.asn};

          ipv4 {
            extended next hop on;

            import filter {
              accept;
            };

            export filter {
              accept;
            };
          };

          ipv6 {
            import filter {
              accept;
            };

            export filter {
              accept;
            };
          };
        }
      '';
    };
  };
}
