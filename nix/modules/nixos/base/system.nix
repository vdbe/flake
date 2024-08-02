{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (inputs) self;
  inherit (lib.modules) mkDefault mkIf;
  inherit (lib.options) mkEnableOption;
  inherit (lib.trivial) warn;

  cfg = config.mymodules.base.system;
in
{
  options.mymodules.base.system = {
    enable = mkEnableOption "basic nixpkgs settings" // {
      default = config.mymodules.base.enable;
      defaultText = lib.literalExpression "config.mymodules.base.enable";
    };
  };

  config = mkIf cfg.enable {
    system = {
      configurationRevision = mkDefault (self.rev or self.dirtyRev or "dirty-unknown");

      stateVersion = mkDefault (
        let
          v = lib.trivial.release;
        in
        warn "Please set system.stateVersion defaulting to ${v}" v
      );
    };

  };
}
