{
  lib,
  pkgs,
  ...
}: {
  services = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        containerName = lib.mkOption {
          type = lib.types.str;
        };

        image = lib.mkOption {
          type = lib.types.str;
        };

        environment = lib.mkOption {
          type = with lib.types; (attrsOf (oneOf [str int]));
        };

        ports = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              externalPort = lib.mkOption {
                type = lib.types.ints.port;
              };

              internalPort = lib.mkOption {
                type = lib.types.ints.port;
              };
            };
          });

          default = [];
        };

        volumes = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              externalVolume = lib.mkOption {
                type = lib.types.ints.str;
              };

              internalVolume = lib.mkOption {
                type = lib.types.ints.str;
              };
            };
          });

          default = [];
        };

        networks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
        };
      };
    });
  };

  networks = lib.mkOption {};
}
