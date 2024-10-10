{ inputs, ... }:
let
  flake-parts =
    inputs.flake-parts or (throw ''missing input `flake-parts.url = "github:hercules-ci/flake-part"`'');

  systems = inputs.systems or (throw ''missing input `systems.url = "github:nix-systems/default"`'');
in
flake-parts.lib.mkFlake { inherit inputs; } {
  systems = import systems;
  debug = true;

  flake.inputs = inputs;

  imports = [
    ./dev
    ./hosts
    ./lib
    ./modules
    ./terra
  ];
}
