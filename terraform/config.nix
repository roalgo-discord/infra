{ lib, ... }:
let
  deployerPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINcre3PZxAV2Zt46k5NTegD4NgyzDnwrxFOr9g5vsUYr";
in
{
  terraform.required_providers.hcloud = {
    source = "registry.terraform.io/hetznercloud/hcloud";
    version = ">= 1.57";
  };

  variable.hcloud_token = {
    description = "Hetzner Cloud API token";
    sensitive = true;
    type = "string";
  };

  provider.hcloud.token = "\${var.hcloud_token}";

  resource.hcloud_ssh_key.deployer = {
    name = "nixos-anywhere-deployer";
    public_key = deployerPubKey;
  };

  resource.hcloud_server.hetzner_vm = {
    name = "hetzner-nixos-anywhere";
    server_type = "cx23";
    image = "ubuntu-24.04";
    location = "nbg1";

    ssh_keys = [ "\${hcloud_ssh_key.deployer.id}" ];

    public_net = {
      ipv4_enabled = true;
      ipv6_enabled = true;
    };
  };

  module.install = {
    source = "github.com/nix-community/nixos-anywhere//terraform/all-in-one";

    nixos_system_attr = "\${path.module}/..#nixosConfigurations.hetzner-vm.config.system.build.toplevel";
    nixos_partitioner_attr = "\${path.module}/..#nixosConfigurations.hetzner-vm.config.system.build.diskoScript";

    kexec_tarball_url = "https://gh-v6.com/nix-community/nixos-images/releases/download/nixos-unstable/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz";

    special_args = {
      terraform = {
        ipv4 = "\${hcloud_server.hetzner_vm.ipv4_address}";
        ipv6 = "\${hcloud_server.hetzner_vm.ipv6_address}";
      };
    };

    target_host = "\${hcloud_server.hetzner_vm.ipv4_address}";

    build_on_remote = true;
    debug_logging = true;
  };

}
