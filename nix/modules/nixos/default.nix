{
  flake.nixosModules = {
    core = ./core;
    base = ./base;
    default = ./default;
    microvm = ./microvm/default.nix;
    microvm-host = ./microvm/host;
    microvm-guest = ./microvm/guest.nix;
  };
}
