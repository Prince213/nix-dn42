{ config, lib, ... }:
let
  cfg = config.networking.dn42;
in
{
  imports = [
    ./babel.nix
    ./bgp.nix
    ./ospf.nix
  ];

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
    routerId = lib.mkOption {
      type = lib.types.str;
      default = cfg.ipv4.address;
      description = "The router ID to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.bird.config = lib.mkBefore ''
      router id ${cfg.routerId};

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
    '';

    services.frr.config = ''
      ip router-id ${cfg.routerId}
    '';

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
            "${cfg.ipv6.address}/64"
          ];
        };
      };
    };
  };
}
