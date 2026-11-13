{ nixpkgs }:
let
  lib = nixpkgs.lib // {
    nixosSystem = args: args;
  };
  root = ./fixtures;
  homeManager = {
    lib.homeManagerConfiguration = args: args;
  };
  selectedNixpkgs = name: {
    lib.nixosSystem = args: args // { selectedInput = name; };
  };
  selectedHomeManager = name: {
    lib.homeManagerConfiguration = args: args // { selectedInput = name; };
  };
  nixLib = (import ../lib { inherit lib; }).mkLib {
    inputs = {
      nixpkgs = nixpkgs.outPath;
      "home-manager" = homeManager;
    };
    inherit root;
    modulesDir = "modules";
    hostsDir = "hosts";
    usersDir = "users";
    vesselsDir = "vessels";
    clankersDir = "clankers";
    hostFeaturesDir = "hosts/features";
    usersFeaturesDir = "users/features";
  };
  hosts = nixLib.mkHosts {
    specs.sample-host.nixpkgs = selectedNixpkgs "host";
  };
  vessels = nixLib.mkVessels {
    specs.sample-vessel.nixpkgs = selectedNixpkgs "vessel";
  };
  clankers = nixLib.mkClankers {
    specs.sample-clanker.home-manager = selectedHomeManager "clanker";
  };
  host = hosts.sample-host;
  vessel = vessels.sample-vessel;
  clanker = clankers."sample-clanker@agent-sample-clanker";
  user =
    (nixLib.mkUsers {
      "sample-user@sample-host" = {
        username = "sample-user";
        hostname = "sample-host";
        inputOverrides.home-manager = selectedHomeManager "user";
      };
    })."sample-user@sample-host";
  featureSet = nixLib.features.mkFeatureSetFromDirs [
    (root + "/multi-features-a")
    (root + "/multi-features-b")
  ];
  processedFeatures = nixLib.features.processFeatures {
    opt-in = [ "extra" ];
    opt-out = [ "legacy" ];
  } featureSet;
in
assert builtins.attrNames hosts == [ "sample-host" ];
assert builtins.attrNames vessels == [ "sample-vessel" ];
assert builtins.attrNames clankers == [ "sample-clanker@agent-sample-clanker" ];
assert builtins.elem (root + "/hosts/sample-host/default.nix") host.modules;
assert builtins.elem (root + "/hosts/sample-host/features/default/core.nix") host.modules;
assert builtins.any (
  module: builtins.isAttrs module && (module.hostSpec.hostname or null) == "sample-host"
) host.modules;
assert builtins.elem (root + "/vessels/sample-vessel/default.nix") vessel.modules;
assert builtins.elem (root + "/vessels/sample-vessel/features/default/core.nix") vessel.modules;
assert builtins.any (
  module: builtins.isAttrs module && (module.hostSpec.hostname or null) == "agent-sample-vessel"
) vessel.modules;
assert builtins.elem (root + "/clankers/sample-clanker/default.nix") clanker.modules;
assert builtins.elem (root + "/clankers/sample-clanker/features/default/core.nix") clanker.modules;
assert builtins.elem (root + "/users/sample-user/default.nix") user.modules;
assert host.selectedInput == "host";
assert vessel.selectedInput == "vessel";
assert clanker.selectedInput == "clanker";
assert user.selectedInput == "user";
assert featureSet.default == [ "shared" ];
assert featureSet.opt-in == [ "extra" ];
assert featureSet.opt-out == [ "legacy" ];
assert
  processedFeatures.enabled == [
    "shared"
    "extra"
  ];
assert
  nixLib.features.resolveFeaturePath [
    (root + "/multi-features-a")
    (root + "/multi-features-b")
  ] "shared" == root + "/multi-features-a/default/shared.nix";
true
