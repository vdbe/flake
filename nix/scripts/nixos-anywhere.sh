#!/usr/bin/env bash

set -e

# Create a temporary directory
extra_files=$(mktemp -d)
keyfile=$(mktemp)
disk_encryption_key=$(mktemp)

cleanup() {
  rm -rf "$extra_files"
  rm -rf "$keyfile"
  rm -rf "$disk_encryption_key"
}
trap cleanup EXIT

abort() {
  echo "aborted: $*" >&2
  exit 1
}

sops_decrypt_key() {
  file="$1"
  key="$2"
  sops --extract '["'$key'"]' --decrypt "$file"
}

flake=".#"

while [[ $# -gt 0 ]]; do
  case "$1" in
  -f | --flake)
    flake=$2
    shift
    ;;
  -s | --system)
    configuration_name=$2
    shift
    ;;

  *)
    if [[ -z ${configuration_name-} ]]; then
      configuration_name="$1"
      shift
    fi
    break 2
    ;;
  esac
  shift
done

if [[ -z ${configuration_name-} ]]; then
  abort "-s/--system needs to be set"
fi

stage0_sops_file="$(nix eval "${flake}nixosConfigurations.${configuration_name}.config.secrets.secretFiles.stage0.file")"
system_stage0_sops_file="$(nix eval "${flake}nixosConfigurations.${configuration_name}.config.mm.b.secrets.host.secretFiles.stage0.file")"
persistence="$(nix eval "${flake}nixosConfigurations.${configuration_name}.config.mm.b.persistence.enable")"

mkdir -p "$extra_files/etc"
if [[ "$persistence" == "true" ]]; then
  required_system_state__persistentStorage_path="$(nix eval --raw "${flake}nixosConfigurations.${configuration_name}.config.environment.persistence.\"state/required/system\".persistentStoragePath")"
  etc_dir="${extra_files}$required_system_state__persistentStorage_path/etc"

  ln --relative --symbolic --force "$etc_dir/machine-id" "$extra_files/etc"
else
  etc_dir="${extra_files}/etc"
fi

sops_decrypt_key "$stage0_sops_file" "age_key" >"$keyfile"

export SOPS_DECRYPTION_ORDER="age"
export SOPS_AGE_KEY_FILE="$keyfile"

mkdir -p "$extra_files/etc" "$etc_dir/ssh"

for keyname in ssh_host_ed25519_key ssh_host_ed25519_key.pub; do
  if [[ $keyname == *.pub ]]; then
    umask 0133
  else
    umask 0177
  fi
  sops_decrypt_key "$system_stage0_sops_file" "$keyname" >"$etc_dir/ssh/$keyname"
done
umask 0022

umask 0333
sops_decrypt_key "$system_stage0_sops_file" "machine_id" >"$etc_dir/machine-id"

sops_decrypt_key "$system_stage0_sops_file" "luks_secret_key" >"$disk_encryption_key"

umask 0222

rm -f "$SOPS_AGE_KEY_FILE"

nix run github:nix-community/nixos-anywhere -- \
  --flake "${flake}${configuration_name}" \
  --extra-files "$extra_files" \
  --disk-encryption-keys "/tmp/secret.key" "$disk_encryption_key" \
  $@
