# lib/default.nix
#
# Main entry point for nix-lib.
# Returns a function that creates the full library given inputs and configuration.
#
{ lib }:
{
  # Create the full library with configuration
  # Usage in consumer flake:
  #   lib = nix-lib.lib.mkLib {
  #     inherit inputs;
  #     root = ./.;
  #   };
  mkLib =
    {
      inputs,
      root,
      # Optional path overrides (relative to root)
      hostsDir ? "hosts",
      usersDir ? "users",
      modulesDir ? "modules",
      overlaysDir ? "overlays",
      pkgsDir ? "pkgs",
      hostFeaturesDir ? "hosts/features",
      usersFeaturesDir ? "users/features",
    }:
    let
      # Build path helpers bound to the consumer's root
      paths = import ./paths.nix {
        inherit lib root;
      };

      # Create pathFromRoot that uses consumer's root
      pathFromRoot = paths.pathFromRoot;

      # Build configured paths
      configuredPaths = {
        inherit
          hostsDir
          usersDir
          modulesDir
          overlaysDir
          pkgsDir
          hostFeaturesDir
          usersFeaturesDir
          ;
        hosts = pathFromRoot hostsDir;
        users = pathFromRoot usersDir;
        modules = pathFromRoot modulesDir;
        overlays = pathFromRoot overlaysDir;
        pkgs = pathFromRoot pkgsDir;
        hostFeatures = pathFromRoot hostFeaturesDir;
        usersFeatures = pathFromRoot usersFeaturesDir;
      };

      # Build the component libs
      features = import ./features.nix { inherit lib; };
      impermanence = import ./impermanence.nix { inherit lib; };
      modules = import ./modules.nix {
        inherit lib inputs;
        paths = configuredPaths;
        pathFromRoot = paths.pathFromRoot;
      };
      packages = import ./packages.nix {
        inherit lib;
        paths = configuredPaths;
        pathFromRoot = paths.pathFromRoot;
      };
      overlays = import ./overlays.nix { inherit lib; };
      builders = import ./builders.nix {
        inherit
          lib
          inputs
          features
          modules
          packages
          overlays
          ;
        paths = configuredPaths;
        pathFromRoot = paths.pathFromRoot;
      };
    in
    {
      # Export all components
      inherit
        paths
        features
        impermanence
        modules
        packages
        overlays
        builders
        ;

      # Convenience exports at top level
      inherit (paths) pathFromRoot relativeToRoot;
      inherit (builders)
        mkSystem
        mkHome
        mkSystems
        mkHomes
        hasFeature
        withFeature
        ;
      inherit (modules) forEachSystem pkgsFor scanModules importModules importIfExists;
    };

  # Re-export component libs for advanced usage
  features = import ./features.nix { inherit lib; };
  impermanence = import ./impermanence.nix { inherit lib; };
  overlays = import ./overlays.nix { inherit lib; };
}
