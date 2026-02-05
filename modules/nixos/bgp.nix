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
    roa = {
      enable = lib.mkEnableOption "ROA checks";
      registry = lib.mkOption {
        type = lib.types.path;
        description = "Path to the DN42 registry.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.bird.config = lib.mkBefore ''
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
          next hop self ebgp;
          extended next hop on;

          import filter {
            ${lib.optionalString cfg.roa.enable ''
              if roa_check(dn42_roa4) != ROA_VALID then reject;
            ''}
            accept;
          };

          export where (source = RTS_STATIC) || (source = RTS_BGP);
        };

        ipv6 {
          next hop self ebgp;

          import filter {
            ${lib.optionalString cfg.roa.enable ''
              if roa_check(dn42_roa6) != ROA_VALID then reject;
            ''}
            accept;
          };

          export where (source = RTS_STATIC) || (source = RTS_BGP);
        };
      }
    '';
  };
}
