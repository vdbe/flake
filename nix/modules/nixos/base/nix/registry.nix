{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (builtins) mapAttrs;
  inherit (lib) types;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.modules) mkIf;
  inherit (lib.options) literalExpression mkEnableOption mkOption;

  cfg = config.mymodules.base.nix.registry;

  registry =
    let
      r = mapAttrs (
        _: v:
        (
          if (v._type == "flake") then
            { flake = v; }
          else
            {
              to = {
                type = "path";
                path = v.outPath;
              };
            }
        )
      ) cfg.entries;
    in
    r // optionalAttrs (cfg.aliasNixpkgs && r ? nixpkgs) { n = r.nixpkgs; };

in
{
  options.mymodules.base.nix.registry = {
    enable = mkEnableOption "basic registry settings" // {
      default = config.mymodules.base.nix.enable;
      defaultText = literalExpression "config.mymodules.base.nix.enable";
    };
    aliasNixpkgs = mkOption {
      type = types.bool;
      default = true;
      description = "Alias `nixpkgs` to `n`";
    };
    filterPred = mkOption {
      type = types.functionTo types.anything;
      default = n: _: lib.strings.hasPrefix "nixpkgs" n;
      defaultText = literalExpression ''n: _: lib.strings.hasPrefix "nixpkgs" n'';
    };
    inputs = mkOption {
      type = types.attrsOf types.attrs;
      default = inputs;
      defaultText = "inputs";
    };
    entries = mkOption {
      type = types.attrs;
      default = lib.attrsets.filterAttrs cfg.filterPred cfg.inputs;
      defaultText = ''lib.attrssets.filterAttrs cfg.filterPred cfg.inputs'';
    };
  };

  config = mkIf cfg.enable { nix.registry = registry; };
}
