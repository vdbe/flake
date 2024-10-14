{
  description = "A very basic flake";

  nixConfig = {
    extra-substituters = [
      "https://vdbe.cachix.org"
      "https://microvm.cachix.org"
      "https://cache.thalheim.io"
    ];
    extra-trusted-public-keys = [
      "vdbe.cachix.org-1:ID9DIbnE6jHyJlQiwS7L7tFULJd1dsxt2ODAWE94nts="
      "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys="
      "cache.thalheim.io-1:R7msbosLEZKrxk/lKxf9BTjOOH7Ax3H0Qj0/6wiHOgc="
    ];
  };

  inputs = {
    # supported systems
    systems.url = "github:nix-systems/default";

    # nixpkgs
    nixpkgs.follows = "nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    mypkgs = {
      url = "github:vdbe/flake-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # terraform
    terranix = {
      url = "github:terranix/terranix/develop";
      # url = "github:vdbe/terranix/dev";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        terranix-examples.follows = "";
        bats-support.follows = "";
        bats-assert.follows = "";
      };
    };

    # Secrets
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-stable.follows = "nixpkgs-stable";
      };
    };

    secrets.url = "git+ssh://git@github.com/vdbe/flake-secrets";
    # secrets = {
    #   # For dev
    #   type = "git";
    #   url = "file:./";
    #   dir = "secrets";
    #   submodules = true;
    # };
    secrets.inputs = {
      systems.follows = "";
    };

    # persistence
    impermanence.url = "github:nix-community/impermanence";

    # file system setup
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # microvim
    microvm = {
      url = "github:astro/microvm.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        spectrum.follows = "";
      };
    };

    # dev
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Support/util inputs
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
  };

  outputs = inputs: import ./nix { inherit inputs; };
}
