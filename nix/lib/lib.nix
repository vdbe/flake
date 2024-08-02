{
  self,
  inputs,
  lib,
  ...
}:
let
  builders = import ./builders.nix { inherit lib inputs self; };
in
{
  inherit builders;
}
