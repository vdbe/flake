{ lib, ... }:
{
  options.mymodules.nestedImports = lib.options.mkEnableOption "Import and apply nested resources";
}
