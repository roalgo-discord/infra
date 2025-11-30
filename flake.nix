{
  description = "RoAlgo infrastructure";

  inputs = {
    srvos.url = "github:nix-community/srvos";

    nixpkgs.follows = "srvos/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";

    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

    aoc-bot = {
      url = "github:susanthenerd/aoc_bot";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      nixpkgs,
      srvos,
      terranix,
      disko,
      agenix,
      agenix-rekey,
      quadlet-nix,
      aoc-bot,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (top: {

      systems = [ "x86_64-linux" ];

      imports = [
        agenix-rekey.flakeModule
        terranix.flakeModule
      ];

      flake = {
        nixosConfigurations.hetzner-vm =
          let
            system = "x86_64-linux";
          in
          nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              srvos.nixosModules.server
              srvos.nixosModules.mixins-systemd-boot

              ./nixos/hetzner-vm.nix
              disko.nixosModules.disko
              agenix.nixosModules.default
              agenix-rekey.nixosModules.default
              quadlet-nix.nixosModules.quadlet
              aoc-bot.nixosModules.default
            ];
          };

        diskoConfigurations.hetzner-vm =
          { ... }:
          {
            imports = [ ./disko/hetzner-vm.nix ];
          };
      };

      perSystem =
        {
          config,
          system,
          pkgs,
          ...
        }:
        {
          terranix.terranixConfigurations."hetzner-vm" = {
            modules = [ ./terraform/config.nix ];

            terraformWrapper.package = pkgs.terraform.withPlugins (p: [
              p.external
              p.local
              p.null
              p.hcloud
            ]);

            terraformWrapper.extraRuntimeInputs = [
              pkgs.nix
              pkgs.git
              pkgs.openssh
              pkgs.jq
            ];

            workdir = "terraform";
          };

          _module.args.pkgs = import self.inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          packages.terraform-config =
            config.terranix.terranixConfigurations."hetzner-vm".result.terraformConfiguration;

          devShells.default = pkgs.mkShell {
            inputsFrom = [
              config.terranix.terranixConfigurations."hetzner-vm".result.devShell
            ];

            nativeBuildInputs = [ config.agenix-rekey.package ];
          };
        };

    });
}
