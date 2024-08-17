{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.services.docker-compose;
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

      services = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "The service name";
            };

            file = lib.mkOption {
              type = lib.types.path;
              description = "The path to the compose file";
            };

            env = lib.mkOption {
              type = lib.types.oneOf (with lib.types; [
                path
                (attrsOf (oneOf [str int]))
              ]);

              default = {};

              description = "Add a .env file to the docker compose config. Can be either a path to the .env file, or just a set specifying the variables";

              example = {
                PORT = 80;
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
      extraGroups = ["docker"];
    };

    systemd.services = builtins.listToAttrs (map ({
        name,
        file,
        env,
      }: {
        name = "${name}-docker";

        value = let
          envFile =
            if lib.isPath env
            then env
            else
              pkgs.writeTextFile {
                name = "${name}-docker-compose-env";
                text = ''
                  ${lib.concatStringsSep "\n" (
                    lib.mapAttrsToList
                    (key: value: "${key}='${toString value}'")
                    env
                  )}
                '';
              };

          compose = "${cfg.package}/bin/docker compose -f ${file} --env-file ${envFile}";
        in {
          description = "${name} docker compose service";
          after = ["multi-user.target"];
          wantedBy = ["multi-user.target"];

          serviceConfig = {
            Type = "simple";
            Restart = "always";
            RemainAfterExit = true;

            User = cfg.user;

            ExecStart = "${compose} up";
            ExecStop = "${compose} down";
          };
        };
      })
      cfg.services);
  };
}
