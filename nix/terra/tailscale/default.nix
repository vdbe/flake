{
  config,
  lib,
  inputs,
  ...
}:
let
  secrets = inputs.secrets.config;

  secret =
    key:
    secrets.extra.terraform.tailscale.${key}
      or (lib.tf.ref ''${config.mymodules.dataSecretsYaml}["tailscale.${key}"]'');

  inherit (config.mymodules.tailscale.tags) tags;
in
{
  imports = [
    inputs.self.terranixModules.tailscale
    ./dns.nix
    ./acl.nix
  ];

  mymodules.tailscale = {
    tailnet = secret "tailnet";
    tags.tagNames = [
      "terranix"
      "desktop"
      "laptop"
      "personal"
      "phone"
      "server"
    ];
    devices = {
      buckbeak = {
        tags = with tags; [
          personal
          desktop
        ];
      };
      norberta = {
        tags = with tags; [
          personal
          laptop
        ];
      };
      phone = {
        tags = with tags; [
          personal
          phone
        ];
      };
      server01 = {
        tags = tags.server;
      };
    };
  };

  provider.tailscale = {
    oauth_client_id = secret "oauth_client_id";
    oauth_client_secret = secret "oauth_client_secret";
  };
}
