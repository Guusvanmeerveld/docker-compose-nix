{
  description = "Use existing docker compose files with Nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {nixpkgs, ...}: {
    nixosModules = {
      default = import ./modules/nixos.nix;
    };
  };
}
