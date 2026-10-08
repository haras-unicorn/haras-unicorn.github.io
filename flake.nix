{
  description = "My GitHub profile README.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem = { pkgs, ... }: {
        devShells.default =
          let
            flake-root = pkgs.writeShellApplication {
              name = "flake-root";
              text = ''
                current="$PWD"
                while [[ "$current" != "/" ]]; do
                  if [[ -f "$current/flake.nix" ]]; then
                    echo "$current"
                    exit 0
                  fi
                  current="$(dirname "$current")"
                done
                echo "no flake.nix found" >&2
                exit 1
              '';
            };

            packages = with pkgs; [
              nil
              nixfmt
              nixos-facter

              github-cli
              nushell
              helix
              opencode
              fd
              ripgrep
              fastmod
              lazygit
              git

              prettier
              yaml-language-server
              vscode-langservers-extracted
              markdownlint-cli
              markdown-link-check
              marksman
              taplo
              cspell

              flake-root
            ];

            devScriptText = pkgs.writeText "dev.nu" ''
              def "main" [] {
                dev -h
              }

              def "main format" [] {
                cd (flake-root)
                prettier --write .
                taplo format ...(fd --hidden --glob '**/*.toml' . | lines)
                nixfmt ...(fd --glob '**/*.nix' . | lines)
              }

              def "main lint" [] {
                prettier --check .
                taplo check ...(fd --hidden --glob '**/*.toml' . | lines)
                nixfmt --check ...(fd --glob '**/*.nix' . | lines)
                cspell lint . --no-progress
                (markdownlint
                  --ignore-path .markdownignore
                  --ignore-path .gitignore
                  .)
                if ($env.NIX_BUILD_TOP? | is-empty) {
                  (markdown-link-check
                    --config .markdown-link-check.json
                    --quiet
                    ...(fd '.*.md' . | lines))
                }
                nix flake check --show-trace
              }
            '';

            devScript = pkgs.writeShellApplication {
              name = "dev";
              runtimeInputs = packages;
              text = ''nu "${devScriptText}" "$@"'';
            };
          in
          pkgs.mkShell {
            packages = packages ++ [ devScript ];
          };

        packages = {
          blog = pkgs.runCommand "blog" {
            src = ./src;
            nativeBuildInputs = [ pkgs.mdbook ];
          } ''mdbook build -d "$out" "$src"'';
        };
      };
    };

  nixConfig = {
    extra-substituters = [
      "https://haras.cachix.org"
    ];
    extra-trusted-public-keys = [
      # cspell:disable
      "haras.cachix.org-1:/HIo1JYqOIH1Nwk1EGXhuPPvDW0WekxIbY5CiXUZbYw="
      # cspell:enable
    ];
  };
}
