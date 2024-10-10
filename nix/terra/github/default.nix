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
    secrets.extra.terraform.github.${key}
      or (lib.tf.ref ''${config.mymodules.dataSecretsYaml}["github.${key}"]'');

in
{
  imports = [
    inputs.self.terranixModules.github
  ];

  mymodules.github = {
    repositories = {
      flake-pkgs = {
        import = true;
        allowAutoMerge = true;
        visibility = "public";

        actions = {
          secrets = {
            CACHIX_AUTH_TOKEN = {
              plain = secret "cachix.auth_token";
            };
            CACHIX_SIGNING_KEY = {
              plain = secret "cachix.signing_key";
            };
          };
        };

        environments = {
          update = {
            branchPolicies = {
              # Only allows environment to be used on the main branch
              main = { };
            };
            secrets = {
              APP_ID = {
                plain = secret "apps.vdbe.id";
              };
              APP_PRIVATE_KEY = {
                plain = secret "apps.vdbe.private_key";
              };
            };
          };
        };

      };
      nvim = {
        import = true;
        actions.secrets = {
          CACHIX_AUTH_TOKEN = {
            plain = secret "cachix.auth_token";
          };
          CACHIX_SIGNING_KEY = {
            plain = secret "cachix.signing_key";
          };
        };
      };
    };
  };
}
