{
  nixosConfig,
  pkgs,
  lib,
  ...
}:
let
  inherit (builtins)
    mapAttrs
    replaceStrings
    attrNames
    attrValues
    ;
  inherit (lib.attrsets) filterAttrs hasAttrByPath;
  inherit (lib.strings) removePrefix concatStringsSep;

  vmConfigs = mapAttrs (_: vm: vm.config.config) nixosConfig.microvm.vms;
  vmConfigsWithStage0 = filterAttrs (
    _: vmConfig:
    hasAttrByPath [
      "mymodules"
      "base"
      "secrets"
      "host"
      "secretFiles"
      "stage0"
    ] vmConfig
  ) vmConfigs;

  decryptStage0StateForVm =
    vmName: vmConfig:
    let
      pathToTag = path: replaceStrings [ "/" ] [ "_" ] (removePrefix "/" path);
      stage0SopsFile = vmConfig.mymodules.base.secrets.host.secretFiles.stage0.file;
      # TODO: get this path from the vm
      persistentStoragePathInVm = if vmConfig.mymodules.base.persistence.enable then "/persist" else "/";
      persistentStorageTagOnHost = pathToTag persistentStoragePathInVm;

      persistentStoragePath =
        if vmConfig.mymodules.base.persistence.enable then
          "${vmName}/${persistentStorageTagOnHost}/state/required/system/"
        else
          "${vmName}/${persistentStorageTagOnHost}";
    in
    # bash
    ''
      # Stage0 for vm ${vmName}
      persistent_storage_path="$microvm_state_dir/${persistentStoragePath}"
      mkdir -p "$persistent_storage_path/etc/ssh"
      for keyname in ssh_host_ed25519_key ssh_host_ed25519_key.pub; do
        if check_if_secret_key_exists "${stage0SopsFile}" "$keyname"; then
          echo "decrypting $keyname for ${vmName}"
        else
          continue
        fi

        if [[ $keyname == *.pub ]]; then
          umask 0133
        else
          umask 0177
        fi

        decrypt_secret_key "${stage0SopsFile}" "$keyname" > "$persistent_storage_path/etc/ssh/$keyname"
        umask 0022
      done

      if check_if_secret_key_exists "${stage0SopsFile}" "machine_id"; then
        echo "decrypting machine-id for ${vmName}"
        umask 0333
        decrypt_secret_key "${stage0SopsFile}" "machine_id" > "$persistent_storage_path/etc/machine-id"
      fi
      umask 0022
    '';

  virtiofsdServices =
    let
      vmNames = attrNames vmConfigsWithStage0;
      serviceNames = map (vmName: "microvm-virtiofsd@${vmName}.service") vmNames;
    in
    concatStringsSep " " serviceNames;

  script = pkgs.writeShellApplication {
    name = "bootstrap-microvms";
    runtimeInputs = with pkgs; [
      sops
      yq
    ];
    text = ''
      check_if_secret_key_exists() {
        secret_file="$1"
        secret_key="$2"

        yq --exit-status "has(\"$secret_key\")" "$secret_file" >/dev/null
      }

      decrypt_secret_key() {
        secret_file="$1"
        secret_key="$2"

        sops --extract "[\"$secret_key\"]" --decrypt "$secret_file"
      }

      sops_stage0_keyfile=$(mktemp)
      trap 'rm -f "$sops_stage0_keyfile"' EXIT
      microvm_state_dir=$(mktemp -d)
      trap 'rm -rf "$microvm_state_dir"' EXIT

      decrypt_secret_key "${nixosConfig.secrets.secretFiles.stage0.file}" "age_key" > "$sops_stage0_keyfile"

      export SOPS_DECRYPTION_ORDER="age"
      export SOPS_AGE_KEY_FILE="$sops_stage0_keyfile"

      ${concatStringsSep "\n" (
        attrValues (
          mapAttrs (vmName: vmConfig: decryptStage0StateForVm vmName vmConfig) vmConfigsWithStage0
        )
      )}

      rm -rf "$SOPS_AGE_KEY_FILE"
      unset SOPS_AGE_KEY_FILE

      # TODO: improve this
      echo "+ starting virtiofsdServices"
      # shellcheck disable=SC2068
      ssh $@ "sudo systemctl start ${virtiofsdServices}"
      echo "+ creating tmpdir"
      # shellcheck disable=SC2068
      remote_tmp_dir=$(ssh $@ "mktemp -d")
      echo "+ copying files tmpdir"
      # shellcheck disable=SC2068,SC2145
      scp -r "$microvm_state_dir"/* $@":$remote_tmp_dir/"
      echo "+ extracting files"
      # shellcheck disable=SC2068,2029
      ssh $@ "sudo sh -c 'cp -a --no-preserve=ownership $remote_tmp_dir/* ${nixosConfig.microvm.stateDir}; rm -rf $remote_tmp_dir'"
    '';
  };
in
script
