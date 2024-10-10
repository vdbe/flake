{ config, lib, ... }:
let
  inherit (builtins) mapAttrs;
  inherit (lib) types tf lists;
  inherit (lib.lists) flatten;
  inherit (lib.trivial) pipe;
  inherit (lib.attrsets)
    mapAttrsToList
    nameValuePair
    optionalAttrs
    ;
  inherit (lib.modules) mkOptionDefault mkForce;
  inherit (lib.options) mkOption mkEnableOption;
  mkNullOption =
    args@{ type, ... }:
    mkOption (
      args
      // {
        type = types.nullOr type;
        default = null;
      }
    );

  submoduleWithSpecialArgs =
    module: specialArgs:
    let
      modules = if builtins.isList module then module else [ module ];
    in
    types.submoduleWith {
      inherit specialArgs modules;
    };

  actionsSecretOpts =
    {
      name,
      parent,
      ...

    }:
    {
      options = {
        import = (mkEnableOption "import secret") // {
          default = parent.import;
        };

        name = mkOption {
          type = types.str;
        };
        plain = mkNullOption {
          type = types.str;
        };
        encrypted = mkNullOption {
          type = types.str;
        };

      };
      config = {
        name = mkOptionDefault name;
      };
    };

  actionsVariableOpts =
    {
      name,
      parent,
      ...

    }:
    {
      options = {
        import = (mkEnableOption "import variable") // {
          default = parent.import;
        };

        name = mkOption {
          type = types.str;
        };
        value = mkOption {
          type = types.str;
        };
      };
      config = {
        name = mkOptionDefault name;
      };
    };

  repositoryDeploymentBranchPolicyOpts =
    {
      name,
      environment,
      ...
    }:
    {
      options = {
        pattern = mkOption { type = types.str; };
        import = (mkEnableOption "import branchPolicy") // {
          default = environment.import;
        };
      };
      config = {
        pattern = mkOptionDefault name;
      };
    };

  repositoryEnvironmentOpts =
    {
      config,
      name,
      repository,
      ...
    }:
    let
      extraResources =
        _:
        {
        };
    in
    {
      options = {
        import = (mkEnableOption "import environments") // {
          default = repository.import;
        };

        name = mkOption { type = types.str; };

        canAdminsByPass = (mkEnableOption "can admins bypass") // {
          default = true;
        };
        preventSelfReview = (mkEnableOption "prevent self review") // {
          default = true;
        };
        # TODO: reviewers
        branchPolicies = mkOption {
          type = types.nullOr (
            types.either types.bool (
              types.attrsOf (
                submoduleWithSpecialArgs repositoryDeploymentBranchPolicyOpts {
                  environment = config;
                }
              )
            )
          );
          default = null;
        };
        secrets = mkOption {
          type = types.attrsOf (
            submoduleWithSpecialArgs
              [
                actionsSecretOpts
                extraResources
                (_: {
                  # Not supported
                  import = mkForce false;
                })
              ]
              {
                parent = config;
              }
          );
          default = { };
        };
        variables = mkOption {
          type = types.attrsOf (
            submoduleWithSpecialArgs
              [
                actionsVariableOpts
                extraResources
              ]
              {
                parent = config;
              }
          );
          default = { };
        };
      };
      config = {
        name = mkOptionDefault name;
      };
    };

  repositoryOpts =
    { config, name, ... }:
    {
      options = {
        import = mkEnableOption "import repository";

        name = mkOption { type = types.str; };
        description = mkNullOption { type = types.str; };
        homepageUrl = mkNullOption { type = types.str; };
        visibility = mkNullOption {
          type = types.enum [
            "public"
            "private"
            "internal"
          ];
        };
        hasDownloads = mkNullOption {
          type = types.bool;
        };
        hasIssues = mkNullOption {
          type = types.bool;
        };
        hasProjects = mkNullOption {
          type = types.bool;
        };
        hasWiki = mkNullOption {
          type = types.bool;
        };
        allowAutoMerge = mkNullOption {
          type = types.bool;
        };
        vulnerabilityAlerts = mkOption {
          type = types.bool;
        };
        topics = mkNullOption {
          type = types.listOf types.str;
        };
        environments = mkOption {
          type = types.attrsOf (
            submoduleWithSpecialArgs repositoryEnvironmentOpts {
              repositoryAttrName = name;
              repository = config;
            }
          );
          default = { };
        };
        actions = {
          secrets = mkOption {
            type = types.attrsOf (
              submoduleWithSpecialArgs
                [
                  actionsSecretOpts
                ]
                {
                  parent = config;
                }
            );
            default = { };
          };
          variables = mkOption {
            type = types.attrsOf (
              submoduleWithSpecialArgs
                [
                  actionsVariableOpts
                ]
                {
                  parent = config;
                  scopeName = "github_actions_variable";
                }
            );
            default = { };
          };
        };
      };
      config = {
        name = mkOptionDefault name;
        # NOTE: https://github.com/integrations/terraform-provider-github/pull/2228
        # vulnerabilityAlerts = mkRef "vulnerability_alerts";
        vulnerabilityAlerts = mkOptionDefault true;
      };
    };

  secretsHasEncrypted =
    secrets: builtins.any (secret: !(builtins.isNull secret.encrypted)) (builtins.attrValues secrets);

  mkNullDefault = val: default: if builtins.isNull val then default else val;
  blockToRef = block: "${block.scope}.${block.name}";
  blocks = mapAttrsToList (
    repositoryAttrName: repository:
    let
      mkRepositoryDataRef = attr: tf.ref "data.${repositoryBlock.scope}.${repositoryBlock.name}.${attr}";
      repositoryId = repository.name;
      repositoryRef = blockToRef repositoryBlock;

      hasEncryptedRepoSecrets = secretsHasEncrypted repository.actions.secrets;
      hasEncryptedEnvSecrets = builtins.any (env: secretsHasEncrypted env.secrets) (
        builtins.attrValues repository.environments
      );
      hasEncryptedSecrets = hasEncryptedRepoSecrets || hasEncryptedEnvSecrets;

      repositoryBlock = {
        name = repositoryAttrName;
        scope = "github_repository";

        data = {
          inherit (repository) name;
        };
        resource = {
          import = repository.import or false;
          id = repository.name;

          inherit (repository) name;
          description = mkNullDefault repository.description (mkRepositoryDataRef "description");
          visibility = mkNullDefault repository.visibility (mkRepositoryDataRef "visibility");
          homepage_url = mkNullDefault repository.homepageUrl (mkRepositoryDataRef "homepage_url");
          has_downloads = mkNullDefault repository.hasDownloads (mkRepositoryDataRef "has_downloads");
          has_issues = mkNullDefault repository.hasIssues (mkRepositoryDataRef "has_issues");
          has_projects = mkNullDefault repository.hasProjects (mkRepositoryDataRef "has_projects");
          has_wiki = mkNullDefault repository.hasWiki (mkRepositoryDataRef "has_wiki");
          allow_auto_merge = mkNullDefault repository.allowAutoMerge (mkRepositoryDataRef "allow_auto_merge");
          topics = mkNullDefault repository.topics (mkRepositoryDataRef "topics");
          # NOTE: https://github.com/integrations/terraform-provider-github/pull/2228
          # vulnerabilityAlerts = mkRef "vulnerability_alerts";
          vulnerability_alerts = mkNullDefault repository.vulnerabilityAlerts (
            mkRepositoryDataRef "vulnerabilityAlerts"
          );
        };
      };

      repositorySecretBlocks = mapAttrsToList (secretAttrName: secret: {
        name = "${repositoryBlock.name}_${secretAttrName}";
        scope = "github_actions_secret";

        resource = {
          import = secret.import or false;
          id = "${repositoryId}/${secret.name}";

          depends_on = [ repositoryRef ];
          repository = mkRepositoryDataRef "name";
          secret_name = secret.name;

          # TODO: default: https://registry.terraform.io/providers/integrations/github/latest/docs/data-sources/actions_variables
          plaintext_value = secret.plain;
          inherit (secret) encrypted;
        };
      }) repository.actions.secrets;

      repositoryVariableBlocks = mapAttrsToList (variableAttrName: variable: {
        name = "${repositoryBlock.name}_${variableAttrName}";
        scope = "github_actions_variable";

        resource = {
          import = variable.import or false;
          id = "${repositoryId}:${variable.name}";

          depends_on = [ repositoryRef ];
          repository = mkRepositoryDataRef "name";
          variable_name = variable.name;

          # TODO: default: https://registry.terraform.io/providers/integrations/github/latest/docs/data-sources/actions_variables
          inherit (variable) value;
        };
      }) repository.actions.variables;

      # NOTE: https://registry.terraform.io/providers/integrations/github/latest/docs/data-sources/repository_environments
      repositoryEnvironmentBlocks = mapAttrsToList (
        repEnvAttrName: repEnv:
        let
          repEnvRef = blockToRef repositoryEnvironmentBlock;
          repositoryEnvironmentBlock = {
            name = "${repositoryBlock.name}_${repEnvAttrName}";
            scope = "github_repository_environment";

            resource =
              {
                import = repEnv.import or false;
                id = "${repositoryId}:${repEnv.name}";

                depends_on = [ repositoryRef ];
                environment = repEnv.name;
                repository = mkRepositoryDataRef "name";
                prevent_self_review = repEnv.preventSelfReview;
                can_admins_bypass = repEnv.canAdminsByPass;
              }
              // (optionalAttrs (!(builtins.isNull repEnv.branchPolicies)) {
                deployment_branch_policy =
                  if (builtins.isBool repEnv.branchPolicies) then
                    {
                      protected_branches = repEnv.branchPolicies;
                      custom_branch_policies = false;

                    }
                  else
                    {
                      protected_branches = false;
                      custom_branch_policies = true;
                    };
              });
          };

          repEnvSecretBlocks = mapAttrsToList (secretAttrName: secret: {
            name = "${repositoryEnvironmentBlock.name}_${secretAttrName}";
            scope = "github_actions_environment_secret";

            resource = {
              import = secret.import or false;
              id = "${repositoryId}:${secret.name}";

              depends_on = [ repEnvRef ];
              repository = mkRepositoryDataRef "name";
              environment = tf.ref "${repEnvRef}.environment";
              secret_name = secret.name;

              # TODO: default: https://registry.terraform.io/providers/integrations/github/latest/docs/data-sources/actions_variables
              plaintext_value = secret.plain;
            };
          }) repEnv.secrets;

          repEnvVariableBlocks = mapAttrsToList (variableAttrName: variable: {
            name = "${repositoryEnvironmentBlock.name}_${variableAttrName}";
            scope = "github_actions_environment_variables";

            resource = {
              import = variable.import or false;
              id = "${repositoryEnvironmentBlock.resource.id}:${variable.name}";

              depends_on = [ repEnvRef ];
              repository = mkRepositoryDataRef "name";
              environment = tf.ref "${repEnvRef}.environment";
              variable_name = variable.name;

              # TODO: default: https://registry.terraform.io/providers/integrations/github/latest/docs/data-sources/actions_environment_variables
              inherit (variable) value;
            };
          }) repEnv.variables;

          dataBranchPolicies = "data.${
            blockToRef (builtins.elemAt branchPoliciesDataBlock 0)
          }.deployment_branch_policies";

          branchPolicyBlocks = lists.optionals (builtins.isAttrs repEnv.branchPolicies) (
            mapAttrsToList (branchPolAttrName: branchPol: {
              name = "${repositoryEnvironmentBlock.name}_${branchPolAttrName}";
              scope = "github_repository_deployment_branch_policy";

              resource = {
                import = branchPol.import or false;
                id =
                  let
                    id' = "\${${dataBranchPolicies}[index(${dataBranchPolicies}.*.name, \"${branchPol.pattern}\")].id}";
                  in
                  # id' = "\${${dataBranchPolicies}[index(${dataBranchPolicies}.*.name, \"main\"].id}";
                  "${repositoryEnvironmentBlock.resource.id}:${id'}";

                inherit (repositoryEnvironmentBlock.resource) repository;
                depends_on = [ repEnvRef ];
                environment_name = tf.ref "${repEnvRef}.environment";
                name = branchPol.pattern;
              };

            }) repEnv.branchPolicies
          );

          branchPoliciesDataBlock = lists.optional (branchPolicyBlocks != [ ]) {
            inherit (repositoryEnvironmentBlock) name;
            scope = "github_repository_deployment_branch_policies";

            data = {
              inherit (repositoryEnvironmentBlock.resource) repository;
              environment_name = repositoryEnvironmentBlock.resource.environment;
              # environment_name = tf.ref "${repEnvRef}.environment";
            };
          };
        in
        [ repositoryEnvironmentBlock ]
        ++ repEnvVariableBlocks
        ++ repEnvSecretBlocks
        ++ branchPolicyBlocks
        ++ branchPoliciesDataBlock
      ) repository.environments;

      # dataRepositoryEnvironments = "data.${
      #   blockToRef (builtins.elemAt repositoryEnvironmentsBlock 0)
      # }.deployment_branch_policies";
      repositoryEnvironmentsBlock = lists.optional (repositoryEnvironmentBlocks != [ [ ] ]) {
        inherit (repositoryBlock) name;
        scope = "github_repository_environments";

        data = {
          repository = tf.ref "data.${blockToRef repositoryBlock}.name";
        };
      };

      repositoryActionPublicKeyBlock = lists.optional hasEncryptedSecrets {
        inherit (repositoryBlock) name;
        scope = "github_actions_public_key";
        repository = tf.ref "data.${blockToRef repositoryBlock}.name";
      };

    in
    [ repositoryBlock ]
    ++ repositoryActionPublicKeyBlock
    ++ repositoryVariableBlocks
    ++ repositorySecretBlocks
    ++ repositoryEnvironmentBlocks
    ++ repositoryEnvironmentsBlock
  ) cfg.repositories;
  groupedBlocks = builtins.groupBy (block: block.scope) (flatten blocks);

  cfg = config.mymodules.github;
in
{
  options.mymodules.github = {
    repositories = mkOption {
      type = types.nullOr (types.attrsOf (types.submodule repositoryOpts));
      default = null;
    };
  };

  config = {
    terraform.required_providers = {
      github.source = "registry.terraform.io/integrations/github";
    };

    provider = {
      github = { };
    };

    import = flatten (
      mapAttrsToList (
        scope: blocks:
        (pipe blocks [
          (builtins.filter (block: (builtins.hasAttr "resource" block) && (block.resource.import or false)))
          (map (block: {
            inherit (block.resource) id;
            to = "${scope}.${block.name}";
          }))
        ])
      ) groupedBlocks
    );

    data = mapAttrs (
      _: blocks:
      (pipe blocks [
        (builtins.filter (block: builtins.hasAttr "data" block))
        (map (block: (nameValuePair block.name block.data)))
        builtins.listToAttrs
      ])
    ) groupedBlocks;

    resource = mapAttrs (
      _: blocks:
      (pipe blocks [
        (builtins.filter (block: builtins.hasAttr "resource" block))
        (map (
          block:
          (nameValuePair block.name (
            builtins.removeAttrs block.resource [
              "id"
              "import"
            ]
          ))
        ))
        builtins.listToAttrs
      ])
    ) groupedBlocks;
  };
}
