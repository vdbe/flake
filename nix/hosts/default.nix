{ self, inputs, ... }:
let
  inherit (builtins) mapAttrs;
  nixpkgs =
    inputs.nixpkgs or (throw ''missing input `nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"`'');

  nixosConfigurations = {
    server01 = ./server01;
    arnold = ./arnold;
    bastion = ./bastion;
    router = ./router;
    # test02 = ./test02;
    # test03 = ./test03;
  };

  unevaluatedNixosConfigurations = mapAttrs (_: path: {
    modules = [ path ];
    specialArgs = {
      inherit inputs;
    };
  }) nixosConfigurations;

  evaluateNixosConfigurations = mapAttrs (
    _: unevaluatedNixosConfiguration: nixpkgs.lib.nixosSystem unevaluatedNixosConfiguration
  );
in
{
  flake = {
    inherit unevaluatedNixosConfigurations;
    nixosConfigurations = evaluateNixosConfigurations self.unevaluatedNixosConfigurations;
  };
}
