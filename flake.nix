# flake.nix
{
  description = "Reusable NixOS/Home Manager library for declarative system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default-linux";
  };

  outputs =
    {
      nixpkgs,
      systems,
      ...
    }:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      # The main lib constructor - users call this with their inputs and root
      lib = import ./lib { inherit (nixpkgs) lib; };

      checks = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lib = nixpkgs.lib;
          nixLib = (import ./lib { inherit lib; }).mkLib {
            inputs = { };
            root = ./.;
          };
          featureSet = {
            default = [ "impermanence" ];
            opt-in = [ "ephemeral-root" ];
            opt-out = [ "legacy-swap" ];
            enabled = [
              "impermanence"
              "legacy-swap"
            ];
          };
          defaultFeatures = nixLib.features.processFeatures { } featureSet;
          selectedFeatures = nixLib.features.processFeatures {
            opt-in = [ "ephemeral-root" ];
            opt-out = [ "legacy-swap" ];
          } featureSet;
          moduleArgs = nixLib.builders.mkSystemSpecialArgs { inputs = { }; };
          persistedDirectory =
            moduleArgs.nix-lib.impermanence.mkPersistDir "/var/lib/example" "svc" "svc"
              "0700";
          persistedFile =
            moduleArgs.nix-lib.impermanence.mkPersistFile "/etc/example.conf" "root" "root"
              "0640";
        in
        assert
          defaultFeatures.enabled == [
            "impermanence"
            "legacy-swap"
          ];
        assert
          selectedFeatures.enabled == [
            "impermanence"
            "ephemeral-root"
          ];
        assert
          persistedDirectory == {
            directory = "/var/lib/example";
            user = "svc";
            group = "svc";
            mode = "0700";
          };
        assert
          persistedFile == {
            file = "/etc/example.conf";
            parentDirectory = {
              user = "root";
              group = "root";
              mode = "0640";
            };
          };
        {
          impermanence-features = pkgs.runCommand "nix-lib-impermanence-features-test" { } ''
            touch "$out"
          '';
        }
      );

      # Formatter for the lib itself
      formatter = forEachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
