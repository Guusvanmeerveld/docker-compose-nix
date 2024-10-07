{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.services.docker-compose;

  docker = lib.getExe cfg.package;

  shared = import ./shared.nix {inherit lib pkgs;};

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

  createNetworkSystemdName = networkName: "docker-network-${networkName}";

  services =
    builtins.mapAttrs (
      name: {
        file,
        env,
        networks,
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

        docker-compose = "${docker} compose --file ${composePackage}/${name}/docker-compose.yaml ${envFileOptions}";

        networkDeps = map (networkName: "${createNetworkSystemdName networkName}.service") networks;
      in {
        description = "${name} docker compose service";
        after = ["docker.service"] ++ networkDeps;
        requires = ["docker.service"] ++ networkDeps;

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

  networks =
    lib.mapAttrs' (
      name: {driver}: (lib.nameValuePair (createNetworkSystemdName name) {
        description = "Create Docker network '${name}'";
        after = ["docker.service"];
        requires = ["docker.service"];

        wantedBy = ["multi-user.target"];

        serviceConfig = {
          Type = "oneshot";

          ExecStart = "${docker} network create ${name} --driver ${driver}";
          ExecStop = "${docker} network rm ${name}";

          RemainAfterExit = true;

          User = cfg.user;
        };
      })
    )
    cfg.networks;
in {
  options = shared.options;

  config = lib.mkIf cfg.enable {
    users.users."${cfg.user}" = lib.mkIf cfg.ensureUser {
      isSystemUser = true;
      group = "docker";
      extraGroups = cfg.groups;
    };

    systemd.services = lib.mkMerge [
      services
      networks
    ];
  };
}
