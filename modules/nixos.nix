{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.services.docker-compose;

  shared = import ./shared.nix;

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
      if lib.isAttrs env
      then (createEnvFile env)
      else env;
  in "--env-file ${file}";
in {
  options = shared.options;

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
          ...
        }: let
          composePackage = pkgs.stdenv.mkDerivation {
            name = "docker-compose-${name}";
            version = "0.1.0";

            phases = ["installPhase"];

            installPhase = ''
              mkdir $out/${name} -p

              cp ${file} $out/${name}/docker-compose.yaml
            '';
          };

          envFileOptions =
            if lib.isList env
            then lib.concatMapStringsSep " " (item: (createEnvOption item)) env
            else createEnvOption env;

          removeOrphansOption = lib.optionalString removeOrphans "--remove-orphans";

          removeImagesOption = lib.optionalString removeImages.enable "--rmi ${removeImages.mode}";

          docker-compose = "${cfg.package}/bin/docker compose --file ${composePackage}/${name}/docker-compose.yaml ${envFileOptions}";
        in {
          description = "${name} docker compose service";
          after = ["multi-user.target"];
          wantedBy = ["multi-user.target"];

          serviceConfig = {
            Type = "simple";
            Restart = "always";
            RemainAfterExit = true;

            User = cfg.user;

            ExecStart = "${docker-compose} up ${removeOrphansOption} --detach";
            ExecStop = "${docker-compose} down ${removeOrphansOption} ${removeImagesOption}";
          };
        }
      )
      cfg.projects;
  };
}
