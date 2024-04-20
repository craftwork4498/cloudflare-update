{
  description = "Cloudflare Update";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
      ];
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        overlayAttrs = {
          inherit (config.packages) cloudflare-update;
        };
        packages.cloudflare-update = pkgs.callPackage ./default.nix {};
        packages.default = config.packages.cloudflare-update;
      };
      flake = {
        nixosModules.default = import ./nixos-module.nix;
      };
    };
}
