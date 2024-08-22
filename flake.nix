{
  description = "NCSG Presentation";

  inputs = {
    devshell = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/devshell";
    };

    flake-utils = {
      inputs.systems.follows = "systems";
      url = "github:numtide/flake-utils";
    };

    git-hooks = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:cachix/git-hooks.nix";
    };

    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      devshell,
      flake-utils,
      nixpkgs,
      self,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          overlays = [ devshell.overlays.default ];
          inherit system;
        };
      in
      {
        apps = {
          build = {
            type = "app";
            program = builtins.toString (
              pkgs.writers.writeBash "build" ''
                ${pkgs.hugo}/bin/hugo -s .
              ''
            );
          };
          develop = {
            type = "app";
            program = builtins.toString (
              pkgs.writers.writeBash "develop" ''
                ${pkgs.hugo}/bin/hugo server
              ''
            );
          };
        };

        checks = {
          git-hooks = self.inputs.git-hooks.lib.${system}.run {
            src = self;
            hooks = {
              # Builtin hooks
              actionlint.enable = true;

              deadnix = {
                enable = true;
                settings.edit = true;
              };

              nixfmt = {
                enable = true;
                package = pkgs.nixfmt-rfc-style;
                settings.width = 80;
              };

              prettier.enable = true;

              typos = {
                enable = true;
                settings = {
                  binary = false;
                  ignored-words = [ ];
                  locale = "en-au";
                };
              };

              # Custom hooks
              statix-write = {
                enable = true;
                name = "Statix Write";
                entry = "${pkgs.statix}/bin/statix fix";
                language = "system";
                pass_filenames = false;
              };

              trufflehog-verified = {
                enable = pkgs.stdenv.isLinux;
                name = "Trufflehog Search";
                entry = "${pkgs.trufflehog}/bin/trufflehog git file://. --since-commit HEAD --only-verified --fail --no-update";
                language = "system";
                pass_filenames = false;
              };
            };
          };
        };

        devShells.default = pkgs.devshell.mkShell {

          devshell.startup.git-hooks.text = self.checks.${system}.git-hooks.shellHook;

          name = "blog shell";

          packages = with pkgs; [
            actionlint
            deadnix
            git-cliff
            go
            hugo
            lix
            nixfmt-rfc-style
            nodePackages.prettier
            statix
            trufflehog
            typos
          ];
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
