{
  inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };
  outputs = {self, nixpkgs, ...}:
  let
    pname = "zellij-sessionizer";
    forAllSystems = cb:
      nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ] (system: cb {pkgs = nixpkgs.legacyPackages.${system}; system = system;});
  in
  {
    packages = forAllSystems ({pkgs, system}: {
      default = self.packages.${system}.c;
      c = pkgs.stdenv.mkDerivation {
        pname = pname;
        version = "0.1";
        src=./c;
        buildInputs = with pkgs; [fzf zellij];
        buildPhase = ''
          gcc nob.c -o nob
          ./nob
        '';
        installPhase = ''
          mkdir -p $out/bin
          cp zellij-sessionizer $out/bin
        '';
      };
      bash = pkgs.writeShellApplication {
        name = pname;
        text = builtins.readFile ./zellij-sessionizer.sh ;
        runtimeInputs = with pkgs; [ fzf zellij ];
      };
    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          ocaml
          opam
        ];
        shellHook = ''
          eval (opam env)
        '';
      };
    });
  };
}
