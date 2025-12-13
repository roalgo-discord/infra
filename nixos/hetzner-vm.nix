{
  terraform,
  config,
  pkgs,
  lib,
  arhiva-educationala,
  ...
}:
{

  imports = [
    ../modules/agenix-rekey.nix
    ../disko/hetzner-vm.nix
  ];

  disko.enableConfig = true;
  networking.hostName = "hetzner-vm";

  time.timeZone = "Etc/UTC";

  services.openssh = {
    enable = true;
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINcre3PZxAV2Zt46k5NTegD4NgyzDnwrxFOr9g5vsUYr"
    ];
    hashedPassword = "$6$vru/Kz/2RFnBeCXQ$FPDE/DET/P2pNfE2bpVsEdDCeMegmeMApE4l3m/2YR9t6qCSrdiTzqUr8aN1gnOTAcYXBQ30NUf3UtqxINmDL.";
  };

  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    grub = {
      enable = true;
      device = "/dev/sda";
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
  };

  boot = {
    initrd = {
      availableKernelModules = [
        "ahci"
        "xhci_pci"
        "virtio_pci"
        "virtio_scsi"
        "sd_mod"
        "sr_mod"
      ];

      kernelModules = [ ];
    };

    kernelModules = [ ];
    extraModulePackages = [ ];
  };

  age = {
    rekey = {
      hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBOhTrGWmPGw1uzwnLfdqjf7eVo4Aqs14xnexW4sfgyo";

      storageMode = "local";
      localStorageDir = ./. + "/../secrets/rekeyed/${config.networking.hostName}";
    };
    secrets.aoc_bot_env.rekeyFile = ./../secrets/aoc_bot.age;
  };

  system.stateVersion = "25.11";

  systemd.network = {
    enable = true;
    networks."30-wan" = {
      matchConfig.Name = "enp1s0";
      networkConfig.DHCP = "no";
      address = [
        "${terraform.ipv4}/32"
        "${terraform.ipv6}/64"
      ];
      routes = [
        {
          Gateway = "172.31.1.1";
          GatewayOnLink = true;
        }
        { Gateway = "fe80::1"; }
      ];
    };
  };

  networking = {
    useDHCP = lib.mkDefault true;

    nat = {
      enable = true;
      internalInterfaces = [ "ve-+" ];
      externalInterface = "enp1s0";
      enableIPv6 = true;
    };
  };

  services.aoc-bot = {
    enable = true;
    environmentFiles = [ config.age.secrets.aoc_bot_env.path ];
  };

  networking.firewall.allowedTCPPorts = [ 80 ];

  services.caddy = {
    enable = true;
    # Only HTTP is needed; TLS will be handled separately if required.
    globalConfig = ''
      {
        auto_https off
      }
    '';

    virtualHosts.":80".extraConfig = ''
      reverse_proxy 10.231.136.2:3000
    '';
  };

  containers.arhiva = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "10.231.136.1";
    localAddress = "10.231.136.2";
    hostAddress6 = "fc00::1";
    localAddress6 = "fc00::2";

    config =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        imports = [ arhiva-educationala.nixosModules.default ];
        services = {
          arhiva-educationala.enable = true;
          resolved.enable = true;
        };

        networking = {
          firewall.allowedTCPPorts = [ 3000 ];

          # Use systemd-resolved inside the container
          # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
          useHostResolvConf = lib.mkForce false;
        };

        system.stateVersion = "25.11";
      };
  };

}
