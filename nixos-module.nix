{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.cloudflare-update;
in
{
  options = {
    services.cloudflare-update = {
      enable = mkEnableOption "Cloudflare Update";
      zones = mkOption {
        type = types.attrsOf
          (types.submodule {
            options = {
              apiKeyPath = mkOption {
                type = types.path;
              };
              records = mkOption {
                type = types.listOf
                  (types.submodule {
                    options = {
                      type = mkOption { type = types.str; default = "A"; };
                      name = mkOption {
                        type = types.str;
                        example = "localhost.example.com";
                      };
                      proxied = mkOption { type = types.bool; default = false; };
                      content = mkOption {
                        type = types.str;
                        example = "127.0.0.1";
                      };
                      comment = mkOption {
                        type = types.str;
                        example = "domain that points to localhost";
                      };
                    };
                  });
              };
            };
          });
      };
    };
  };
  config =
    let
      cloudflareConf = pkgs.writeText "cloudflare.json" (builtins.toJSON cfg.zones);
    in
    mkIf cfg.enable {
      systemd.services.cloudflare = {
        enable = true;
        description = "update cloudflare records";
        unitConfig = {
          Type = "simple";
        };
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        script = toString (map
          (zoneName: "${pkgs.cloudflare-update}/bin/cloudflare-update ${cloudflareConf} ${zoneName}\n")
          (attrNames cfg.zones));
      };
    };
}
