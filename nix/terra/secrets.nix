{ inputs, ... }:
{
  mymodules.sopsFile = inputs.secrets.config.secretFiles.terraform.file;
}
