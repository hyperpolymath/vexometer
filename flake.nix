# SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Vexometer - Irritation Surface Analyser
# Nix Flake for reproducible development environment

{
  description = "Vexometer - Irritation Surface Analyser for AI assistants";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";

    # Ada/SPARK toolchain
    alire.url = "github:alire-project/alire";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # GNAT toolchain
        gnat = pkgs.gnat;
        gprbuild = pkgs.gprbuild;

        # GtkAda dependencies
        gtkada = pkgs.gtkada;
        gtk3 = pkgs.gtk3;

        # Development tools
        devTools = with pkgs; [
          # Ada toolchain
          gnat
          gprbuild
          gnatprove  # SPARK prover

          # GUI dependencies
          gtk3
          gtkada
          cairo
          pango

          # Build tools
          gnumake
          just

          # Documentation
          asciidoctor

          # Testing
          aunit

          # Networking (for API clients)
          curl
          openssl

          # Version control
          git

          # Container support
          podman

          # Utilities
          jq
          yq
          shellcheck
        ];

      in {
        devShells.default = pkgs.mkShell {
          name = "vexometer-dev";

          buildInputs = devTools;

          shellHook = ''
            echo "🔬 Vexometer Development Environment"
            echo "   Ada 2022 with GtkAda"
            echo ""
            echo "Commands:"
            echo "  just build    - Build the project"
            echo "  just test     - Run tests"
            echo "  just run      - Run Vexometer"
            echo "  just validate - Check RSR compliance"
            echo ""

            # Set up Ada environment
            export ADA_PROJECT_PATH="${gtkada}/share/gpr:$ADA_PROJECT_PATH"
            export GPR_PROJECT_PATH="${gtkada}/share/gpr:$GPR_PROJECT_PATH"

            # Ensure local bin is in path
            export PATH="$PWD/bin:$PATH"
          '';

          # Environment variables
          VEXOMETER_BUILD_MODE = "debug";
        };

        packages.default = pkgs.stdenv.mkDerivation {
          pname = "vexometer";
          version = "0.2.0-dev";

          src = ./.;

          buildInputs = [ gnat gprbuild gtkada gtk3 ];

          buildPhase = ''
            gprbuild -P vexometer.gpr -XVEXOMETER_BUILD_MODE=release
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp bin/vexometer $out/bin/

            mkdir -p $out/share/vexometer
            cp -r data/* $out/share/vexometer/
          '';

          meta = with pkgs.lib; {
            description = "Irritation Surface Analyser for AI assistants";
            homepage = "https://gitlab.com/hyperpolymath/vexometer";
            license = licenses.agpl3Plus;
            maintainers = [ ];
            platforms = platforms.linux;
          };
        };

        # Container image
        packages.container = pkgs.dockerTools.buildImage {
          name = "vexometer";
          tag = "latest";

          contents = [ self.packages.${system}.default ];

          config = {
            Cmd = [ "/bin/vexometer" ];
            WorkingDir = "/";
          };
        };
      }
    );
}
