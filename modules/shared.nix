{
  lib,
  pkgs,
  ...
}: let
  envType = with lib.types; [
    str
    path
    (attrsOf (oneOf [str int]))
  ];
in {
  options = {
    services.docker-compose = {
      enable = lib.mkEnableOption "Enable docker compose service";

      package = lib.mkPackageOption pkgs "docker" {};

      user = lib.mkOption {
        type = lib.types.str;
        default = "docker-compose";

        description = "The user to run the service as";
      };

      ensureUser = lib.mkOption {
        type = lib.types.bool;
        default = true;

        description = "Whether to create the specified the user";
      };

      groups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];

        description = "Extra groups the user that is running the services should be a part of";
      };

      globalEnv = lib.mkOption {
        type = lib.types.oneOf (envType ++ [(lib.types.listOf (lib.types.oneOf envType))]);
        default = [];
        description = "Set environmental variables for ALL listed projects";
      };

      projects = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            file = lib.mkOption {
              type = lib.types.path;
              description = "The path to the compose file";
            };

            env = lib.mkOption {
              type = lib.types.oneOf (envType ++ [(lib.types.listOf (lib.types.oneOf envType))]);

              default = [];

              description = "Add a .env file to the docker compose config. Can be either a path to the .env file, or just a set specifying the variables";

              example = {
                PORT = 80;
              };
            };

            networks = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];

              description = "Networks that this docker compose file depends on";
            };

            removeOrphans = lib.mkOption {
              type = lib.types.bool;
              default = true;

              description = "Whether to add the remove orphans option: Remove containers for services not defined in the Compose file";
            };

            removeImages = {
              enable = lib.mkEnableOption ''Remove images used by services. "local" remove only images that don't have a custom tag ("local"|"all")'';

              mode = lib.mkOption {
                type = lib.types.enum ["local" "all"];
                default = "all";
              };
            };

            logToService = lib.mkEnableOption "Whether to follow the log of the docker compose file in the systemd service";
          };
        });

        default = {};
      };

      networks = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            driver = lib.mkOption {
              type = lib.types.enum ["bridge" "host" "none" "overlay" "ipvlan" "macvlan"];
              default = "bridge";

              description = "Driver to manage the network";
            };

            ip-range = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];

              description = "Allocate container ip from a sub-range";
            };

            subnet = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];

              description = "Subnet in CIDR format that represents a network segment";
            };
          };
        });

        default = {};
      };
    };
  };
}
