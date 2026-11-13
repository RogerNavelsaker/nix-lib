# lib/builders.nix
#
# System and Home Manager configuration builders.
#
{
  lib,
  inputs,
  features,
  impermanence,
  modules,
  packages,
  overlays,
  paths,
  pathFromRoot,
}:
let
  featuresLib = features;

  # Build the nix-lib attrset that gets passed to all modules via specialArgs
  # This provides access to all custom lib functions in modules
  mkNixLibAttr = {
    # Module utilities (flattened for convenience)
    inherit (modules) scanModules importModules importIfExists;

    # Feature system and impermanence helpers
    inherit features impermanence;

    # Package utilities (flattened for convenience)
    inherit (packages) buildPackageSet discoverPackages;

    # Overlay utilities (flattened for convenience)
    inherit (overlays) mkChannelOverlay;

    # Path utilities (flattened for convenience)
    inherit pathFromRoot;
  };
in
rec {
  discoverResourceDirs =
    root:
    if builtins.pathExists root then
      lib.filterAttrs (
        name: kind: kind == "directory" && builtins.pathExists (root + "/${name}/default.nix")
      ) (builtins.readDir root)
    else
      { };

  mkDiscoveredResources =
    {
      root,
      builder,
      defaults ? { },
      specs ? { },
      resources ? null,
      exclude ? [ ],
    }:
    let
      discovered = builtins.attrNames (discoverResourceDirs root);
      names = builtins.filter (name: !(builtins.elem name exclude)) (
        if resources == null then discovered else resources
      );
    in
    lib.genAttrs names (name: builder (defaults // (specs.${name} or { }) // { resourceName = name; }));
  # Build base specialArgs common to both NixOS and Home Manager
  mkBaseSpecialArgs =
    {
      inputs,
      extraSpecialArgs ? { },
    }:
    let
      inputsWithoutSelf = builtins.removeAttrs inputs [ "self" ];
    in
    {
      inputs = inputsWithoutSelf;
      # Pass nix-lib to all modules
      nix-lib = mkNixLibAttr;
    }
    // extraSpecialArgs;

  # Build NixOS-specific specialArgs
  mkSystemSpecialArgs =
    {
      inputs,
      secrets ? null,
      extraSpecialArgs ? { },
    }:
    mkBaseSpecialArgs {
      inherit inputs extraSpecialArgs;
    }
    // (if secrets != null then { inherit secrets; } else { });

  # Build Home Manager-specific extraSpecialArgs
  mkHomeExtraSpecialArgs =
    {
      inputs,
      secrets ? null,
      extraSpecialArgs ? { },
    }:
    let
      inputsWithoutSelf = builtins.removeAttrs inputs [ "self" ];
    in
    {
      inputs = inputsWithoutSelf;
      # Pass nix-lib to all modules
      nix-lib = mkNixLibAttr;
    }
    // (if secrets != null then { inherit secrets; } else { })
    // extraSpecialArgs;

  # Collect NixOS system modules
  mkSystemModules =
    {
      hostname,
      users,
      stateVersion,
      domain ? null,
      secrets ? null,
      featuresBasePaths,
      resourceDir ? paths.hosts,
      resourceName ? hostname,
      systemInputs ? inputs,
      enabledFeatures,
      overlays,
      extraModules ? [ ],
      standaloneHM ? true,
      userFeatures ? { },
      userFeaturesBasePaths ? [ paths.usersFeatures ], # For integrated HM mode
    }:
    let
      # Host config: check both patterns
      # 1. hosts/{hostname}/default.nix (directory)
      # 2. hosts/{hostname}.nix (file)
      hostConfigDir = resourceDir + "/${resourceName}";
      hostConfigDirFile = hostConfigDir + "/default.nix";
      hostConfigFile = resourceDir + "/${resourceName}.nix";
      hostModules =
        if builtins.pathExists hostConfigDirFile then
          [ hostConfigDirFile ]
        else if builtins.pathExists hostConfigFile then
          [ hostConfigFile ]
        else
          [ ];
      featureModules = featuresLib.resolveFeatureModules featuresBasePaths enabledFeatures;

      # Home Manager as NixOS module (integrated mode)
      # Resolve user features for integrated mode with opt-in/opt-out support
      userFeatureSet = featuresLib.processFeatures userFeatures (
        featuresLib.mkFeatureSetFromDirs userFeaturesBasePaths
      );
      userEnabledFeatures = userFeatureSet.enabled;
      userFeatureModules = featuresLib.resolveFeatureModules userFeaturesBasePaths userEnabledFeatures;

      homeManagerModule =
        if !standaloneHM then
          [
            systemInputs.home-manager.nixosModules.home-manager
            (_: {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";
                verbose = true;
                extraSpecialArgs = {
                  inputs = builtins.removeAttrs systemInputs [ "self" ];
                  # Pass nix-lib to integrated Home Manager modules
                  nix-lib = mkNixLibAttr;
                };
                users = builtins.listToAttrs (
                  map (user: {
                    name = user;
                    value = {
                      imports = [
                        (pathFromRoot "${paths.modulesDir}/home-manager")
                        {
                          userSpec = {
                            username = user;
                            inherit hostname stateVersion;
                            enabledFeatures = userEnabledFeatures;
                          };
                          home = {
                            username = user;
                            inherit stateVersion;
                            homeDirectory = if user == "root" then "/root" else "/home/${user}";
                          };
                          programs.home-manager.enable = true;
                        }
                      ]
                      # User features (default + opt-out)
                      ++ userFeatureModules
                      # User-specific host config
                      ++ modules.importIfExists (pathFromRoot "${paths.usersDir}/${user}/${hostname}.nix");
                    };
                  }) users
                );
              };
            })
          ]
        else
          [ ];

      # Auto-configure user passwords from secrets
      sopsModule = if secrets != null then [ systemInputs.sops-nix.nixosModules.sops ] else [ ];

      userPasswordModule =
        if secrets != null && users != [ ] then
          [
            (
              { config, ... }:
              {
                sops.secrets = builtins.listToAttrs (
                  map (user: {
                    name = "${user}-password";
                    value = {
                      sopsFile = secrets + "/users/${user}/secrets.yaml";
                      key = "password";
                      neededForUsers = true;
                    };
                  }) users
                );

                users.users = builtins.listToAttrs (
                  map (user: {
                    name = user;
                    value = {
                      hashedPasswordFile = config.sops.secrets."${user}-password".path;
                    };
                  }) users
                );
              }
            )
          ]
        else
          [ ];

      # Disable root password if root is not in users list
      rootPasswordModule =
        if !(builtins.elem "root" users) then
          [
            {
              users.users.root.hashedPassword = "!";
            }
          ]
        else
          [ ];
    in
    [
      # Import the hostSpec module
      (pathFromRoot "${paths.modulesDir}/nixos")
      # Set hostSpec configuration
      {
        hostSpec = {
          inherit
            hostname
            users
            stateVersion
            domain
            enabledFeatures
            ;
        };
      }
      # Set traditional options from hostSpec
      {
        networking.hostName = lib.mkDefault hostname;
        system.stateVersion = lib.mkDefault stateVersion;
      }
      {
        nixpkgs.overlays = overlays;
        nixpkgs.config.allowUnfree = true;
      }
    ]
    ++ (if domain != null then [ { networking.domain = domain; } ] else [ ])
    ++ sopsModule
    ++ userPasswordModule
    ++ rootPasswordModule
    ++ hostModules
    ++ featureModules
    ++ homeManagerModule
    ++ extraModules;

  # Collect Home Manager modules
  mkHomeModules =
    {
      username,
      hostname,
      stateVersion,
      secrets ? null,
      featuresBasePaths,
      resourceDir ? paths.users,
      resourceName ? username,
      homeInputs ? inputs,
      enabledFeatures,
      overlays,
      extraModules ? [ ],
    }:
    let
      userConfigDir = resourceDir + "/${resourceName}";

      # Host-specific config: check both patterns
      # 1. users/{username}/{hostname}.nix (file)
      # 2. users/{username}/{hostname}/default.nix (directory)
      userHostFile = userConfigDir + "/${hostname}.nix";
      userHostDirFile = userConfigDir + "/${hostname}/default.nix";
      userHostModules =
        if builtins.pathExists userHostDirFile then
          [ userHostDirFile ]
        else if builtins.pathExists userHostFile then
          [ userHostFile ]
        else
          [ ];

      userModules =
        lib.optional (builtins.pathExists (userConfigDir + "/default.nix")) (userConfigDir + "/default.nix")
        ++ userHostModules;
      featureModules = featuresLib.resolveFeatureModules featuresBasePaths enabledFeatures;

      # Auto-configure user SSH key from secrets
      sopsModule = if secrets != null then [ homeInputs.sops-nix.homeManagerModules.sops ] else [ ];

      sshKeyModule =
        if secrets != null then
          [
            (
              { config, ... }:
              {
                sops.secrets."${username}-ssh-key" = {
                  sopsFile = secrets + "/users/${username}/secrets.yaml";
                  key = "ssh/private_key";
                  path = "${config.home.homeDirectory}/.ssh/id_ed25519";
                  mode = "0600";
                };
              }
            )
          ]
        else
          [ ];
    in
    [
      # Import the userSpec module
      (pathFromRoot "${paths.modulesDir}/home-manager")
      # Set userSpec configuration
      {
        userSpec = {
          inherit
            username
            hostname
            stateVersion
            enabledFeatures
            ;
        };
      }
      # Set traditional options from userSpec
      {
        home = {
          inherit username stateVersion;
          homeDirectory = if username == "root" then "/root" else "/home/${username}";
        };
        programs.home-manager.enable = true;
        nixpkgs.overlays = overlays;
      }
    ]
    ++ sopsModule
    ++ sshKeyModule
    ++ userModules
    ++ featureModules
    ++ extraModules;

  # System builder (thin wrapper)
  mkSystem =
    {
      hostname,
      resourceDir ? paths.hosts,
      resourceName ? hostname,
      featuresBasePaths ? [ paths.hostFeatures ],
      userFeaturesBasePaths ? [ paths.usersFeatures ],
      users ? [ ],
      system ? "x86_64-linux",
      stateVersion ? "25.05",
      domain ? null,
      secrets ? null,
      features ? { },
      userFeatures ? { }, # For integrated HM mode: user feature opt-in/opt-out
      extraModules ? [ ],
      extraSpecialArgs ? { },
      overlays ? [ ],
      standaloneHM ? true,
      inputOverrides ? { },
    }:
    let
      systemInputs = inputs // inputOverrides;
      featureSet = featuresLib.processFeatures features (
        featuresLib.mkFeatureSetFromDirs featuresBasePaths
      );

      allOverlays = packages.combineOverlays {
        inputs = systemInputs;
        custom = overlays;
      };

      specialArgs = mkSystemSpecialArgs {
        inputs = systemInputs;
        inherit secrets extraSpecialArgs;
      };

      systemModules = mkSystemModules {
        inherit
          hostname
          resourceDir
          resourceName
          users
          stateVersion
          domain
          secrets
          extraModules
          standaloneHM
          featuresBasePaths
          userFeatures
          userFeaturesBasePaths
          ;
        systemInputs = systemInputs;
        enabledFeatures = featureSet.enabled;
        overlays = allOverlays;
      };
    in
    systemInputs.nixpkgs.lib.nixosSystem {
      inherit system specialArgs;
      modules = systemModules;
    };

  # Home builder (thin wrapper)
  mkHome =
    {
      username,
      resourceDir ? paths.users,
      resourceName ? username,
      featuresBasePaths ? [ paths.usersFeatures ],
      hostname,
      system ? "x86_64-linux",
      stateVersion ? "25.05",
      secrets ? null,
      features ? { },
      extraModules ? [ ],
      extraSpecialArgs ? { },
      overlays ? [ ],
      inputOverrides ? { },
    }:
    let
      homeInputs = inputs // inputOverrides;
      featureSet = featuresLib.processFeatures features (
        featuresLib.mkFeatureSetFromDirs featuresBasePaths
      );

      allOverlays = packages.combineOverlays {
        inputs = homeInputs;
        custom = overlays;
      };
      pkgs = packages.mkPkgs {
        system = system;
        inputs = homeInputs;
        overlays = allOverlays;
        extendedLib = lib;
      };

      homeExtraSpecialArgs = mkHomeExtraSpecialArgs {
        inputs = homeInputs;
        inherit secrets extraSpecialArgs;
      };

      homeModules = mkHomeModules {
        inherit
          username
          resourceDir
          resourceName
          hostname
          stateVersion
          secrets
          extraModules
          featuresBasePaths
          ;
        homeInputs = homeInputs;
        enabledFeatures = featureSet.enabled;
        overlays = allOverlays;
      };
    in
    homeInputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = homeExtraSpecialArgs;
      modules = homeModules;
    };
  # Resource-tree wrappers. Resource IDs are discovered from directories containing default.nix.
  resourceInputOverrides =
    spec:
    (spec.inputOverrides or { })
    // lib.optionalAttrs (spec ? nixpkgs) { nixpkgs = spec.nixpkgs; }
    // lib.optionalAttrs (spec ? home-manager) { home-manager = spec.home-manager; };
  mkHost =
    spec:
    let
      resourceName =
        spec.resourceName or (spec.hostname or (throw "mkHost requires resourceName or hostname"));
      hostFeatures =
        spec.featuresBasePaths or [
          (paths.hosts + "/${resourceName}/features")
          paths.hostFeatures
        ];
    in
    mkSystem (
      builtins.removeAttrs spec [
        "name"
        "nixpkgs"
        "home-manager"
        "inputOverrides"
      ]
      // {
        inputOverrides = resourceInputOverrides spec;
      }
      // {
        inherit resourceName;
        hostname = spec.hostname or resourceName;
        resourceDir = paths.hosts;
        featuresBasePaths = hostFeatures;
      }
    );

  mkVessel =
    spec:
    let
      resourceName = spec.resourceName or (spec.name or (throw "mkVessel requires resourceName or name"));
      vesselFeatures = spec.featuresBasePaths or [ (paths.vessels + "/${resourceName}/features") ];
    in
    mkSystem (
      builtins.removeAttrs spec [
        "name"
        "nixpkgs"
        "home-manager"
        "inputOverrides"
      ]
      // {
        inputOverrides = resourceInputOverrides spec;
      }
      // {
        inherit resourceName;
        hostname = spec.hostname or "agent-${resourceName}";
        resourceDir = paths.vessels;
        featuresBasePaths = vesselFeatures;
      }
    );

  mkClanker =
    spec:
    let
      resourceName =
        spec.resourceName
          or (spec.name or (spec.username or (throw "mkClanker requires resourceName, name, or username")));
      clankerFeatures = spec.featuresBasePaths or [ (paths.clankers + "/${resourceName}/features") ];
    in
    mkHome (
      builtins.removeAttrs spec [
        "name"
        "nixpkgs"
        "home-manager"
        "inputOverrides"
      ]
      // {
        inputOverrides = resourceInputOverrides spec;
      }
      // {
        username = spec.username or resourceName;
        hostname = spec.hostname or "agent-${resourceName}";
        inherit resourceName;
        resourceDir = paths.clankers;
        featuresBasePaths = clankerFeatures;
      }
    );

  mkUser =
    spec:
    let
      username =
        spec.username
          or (spec.resourceName or (spec.name or (throw "mkUser requires username, resourceName, or name")));
      resourceName = spec.resourceName or username;
      userFeatures =
        spec.featuresBasePaths or [
          (paths.users + "/${resourceName}/features")
          paths.usersFeatures
        ];
    in
    mkHome (
      builtins.removeAttrs spec [
        "name"
        "nixpkgs"
        "home-manager"
        "inputOverrides"
      ]
      // {
        inputOverrides = resourceInputOverrides spec;
      }
      // {
        inherit username resourceName;
        resourceDir = paths.users;
        featuresBasePaths = userFeatures;
      }
    );

  mkHosts =
    args:
    mkDiscoveredResources {
      root = paths.hosts;
      builder = mkHost;
      defaults = args.defaults or { };
      specs = args.specs or { };
      resources = args.resources or null;
      exclude = args.exclude or [ ];
    };

  mkVessels =
    args:
    mkDiscoveredResources {
      root = paths.vessels;
      builder = mkVessel;
      defaults = args.defaults or { };
      specs = args.specs or { };
      resources = args.resources or null;
      exclude = args.exclude or [ ];
    };

  mkClankers =
    args:
    let
      clankers = mkDiscoveredResources {
        root = paths.clankers;
        builder = mkClanker;
        defaults = args.defaults or { };
        specs = args.specs or { };
        resources = args.resources or null;
        exclude = args.exclude or [ ];
      };
    in
    lib.mapAttrs' (
      name: clanker:
      let
        spec = (args.defaults or { }) // (args.specs.${name} or { });
        username = spec.username or name;
        hostname = spec.hostname or "agent-${name}";
      in
      lib.nameValuePair "${username}@${hostname}" clanker
    ) clankers;

  # User outputs are explicit because each home maps a human account to a hostname.
  mkUsers = homeSpecs: lib.mapAttrs (_: mkUser) homeSpecs;

  # Batch create multiple systems
  mkSystems = systemSpecs: lib.mapAttrs (_: mkSystem) systemSpecs;

  # Batch create multiple homes
  mkHomes = homeSpecs: lib.mapAttrs (_: mkHome) homeSpecs;

  # Create home-manager switch apps from homeConfigurations
  # Usage: apps = lib.mkHomeApps { inherit self; default = "rona@aio"; };
  mkHomeApps =
    {
      self,
      homeConfigurations ? self.homeConfigurations,
      default ? null,
    }:
    let
      # Create app for a single home configuration
      mkHomeSwitch = name: {
        type = "app";
        program = "${homeConfigurations.${name}.activationPackage}/activate";
      };

      # Generate apps for all home configurations
      homeApps = lib.mapAttrs' (name: _: {
        name = "home-switch-${lib.replaceStrings [ "@" ] [ "-" ] name}";
        value = mkHomeSwitch name;
      }) homeConfigurations;

      # Add default app if specified
      defaultApp =
        if default != null && homeConfigurations ? ${default} then
          { home-switch = mkHomeSwitch default; }
        else
          { };
    in
    homeApps // defaultApp;

  # Utility to check if feature is enabled
  hasFeature = feature: enabledFeatures: lib.elem feature enabledFeatures;

  # Conditional module import based on feature
  withFeature =
    feature: module: enabledFeatures:
    lib.optional (hasFeature feature enabledFeatures) module;
}
