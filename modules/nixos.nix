{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.services.docker-compose;

  envType = with lib.types; [
    path
    (attrsOf (oneOf [str int]))
  ];

  createEnvFile = env:
    pkgs.writeTextFile {
      name = "docker-compose-env";
      text = ''
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList
          (key: value: "${key}='${toString value}'")
          env
        )}
      '';
    };

  createEnvOption = env: let
    file =
      if lib.isPath env
      then env
      else (createEnvFile env);
  in "--env-file ${file}";
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
          };
        });

        default = [];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.users."${cfg.user}" = lib.mkIf cfg.ensureUser {
      isSystemUser = true;
      group = "docker";
    };

    systemd.services =
      builtins.mapAttrs (
        name: {
          file,
          env,
          removeOrphans,
          removeImages,
        }: let
          envFileOptions =
            if lib.isList env
            then lib.concatMapStringsSep " " (item: (createEnvOption item)) env
            else createEnvOption env;

          removeOrphansOption = lib.optionalString removeOrphans "--remove-orphans";

          removeImagesOption = lib.optionalString removeImages.enable "--rmi ${removeImages.mode}";

          compose = "${cfg.package}/bin/docker compose -f ${file} ${envFileOptions}";
        in {
          description = "${name} docker compose service";
          after = ["multi-user.target"];
          wantedBy = ["multi-user.target"];

          serviceConfig = {
            Type = "simple";
            Restart = "always";
            RemainAfterExit = true;

            User = cfg.user;

            ExecStart = "${compose} up ${removeOrphansOption}";
            ExecStop = "${compose} down ${removeOrphansOption} ${removeImagesOption}";
          };
        }
      )
      cfg.projects;
  };
}
