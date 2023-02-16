# Flake definition:
# https://nixos.wiki/wiki/Flakes

{
  description = "cloudflared tunnel using an access token";

  inputs = { nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; };

  outputs = { self, nixpkgs }:
    let
      # Explicit list of supported systems. Add systems when necessary.
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      # Function which generates an attribute set: '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        });
    in {
      nixosModules.cfdtunnel = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.services.cfdtunnel;

          cfgService = {
            DynamicUser = true;
            User = cfg.user;
            Group = cfg.group;
            Restart = "on-failure";
            RestartSecs = "5s";
          };
        in {
          options.services.cfdtunnel = {
            enable = mkEnableOption (lib.mdDoc "cloudflared tunnel");

            package = lib.mkOption {
              type = lib.types.package;
              default = pkgs.cloudflared;
              defaultText = lib.literalExpression "pkgs.cloudflared";
              description = lib.mdDoc "Package to use for cloudflared.";
            };

            token = mkOption {
              type = with types; nullOr str;
              default = null;
              description = lib.mdDoc ''
                Access token
              '';
            };

            user = lib.mkOption {
              default = "cloudflared";
              type = lib.types.str;
              description = lib.mdDoc ''
                User which the service will run as. If it is set to "cloudflared", that
                user will be created.
              '';
            };

            group = lib.mkOption {
              default = "cloudflared";
              type = lib.types.str;
              description = lib.mdDoc ''
                Group which the service will run as. If it is set to "cloudflared", that
                group will be created.
              '';
            };
          };

          config = lib.mkIf cfg.enable {
            systemd.services.cfdtunnel = {
              after = [ "network.target" "network-online.target" ];
              wants = [ "network.target" "network-online.target" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                ExecStart = "${cfg.package}/bin/cloudflared --protocol quic tunnel --no-autoupdate run --token ${cfg.token}";
              } // cfgService;
            };

            users.users = lib.mkIf (cfg.user == "cloudflared") {
                cloudflared = {
                  isSystemUser = true;
                  home = cfg.package;
                  inherit (cfg) group;
                };
              };

            users.groups = lib.mkIf (cfg.group == "cloudflared") {
                cloudflared = { };
              };
          };
        };
    };
}
