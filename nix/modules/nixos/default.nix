{
  flake.nixosModules = {
    core = ./core;
    base = ./base;
    default = ./default;
  };
}
