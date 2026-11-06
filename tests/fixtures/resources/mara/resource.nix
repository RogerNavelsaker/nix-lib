{ inputs, ... }:
{
  hostname = "agent-mara";
  nixpkgs = inputs.maraNixpkgs;
  home-manager = inputs.maraHomeManager;
  inputOverrides = {
    toolchain = inputs.maraToolchain;
  };
}
