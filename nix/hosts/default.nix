{ inputs, ... }:
let
  nixpkgs =
    inputs.nixpkgs or (throw ''missing input `nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"`'');
in
{
  flake = {
    nixosConfigurations = {
      server01 = nixpkgs.lib.nixosSystem {
        modules = [ ./server01 ];
        specialArgs = {
          inherit inputs;
        };
      };
    };
  };
}
