{
  inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };
  outputs = {self, nixpkgs, ...}: let
    pname = "zellij-sessionizer";
    forAllSystems = cb:
      nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ] (system: cb {pkgs = nixpkgs.legacyPackages.${system}; system = system;});
  in {
    packages = forAllSystems ({pkgs, system}:
    {
      default = self.packages.${system}.c;
      c = let
          build = pkgs.stdenv.mkDerivation {
            pname = pname;
            version = "0.1";
            src=./c;
            nativeBuildInputs = with pkgs; [makeWrapper];
            buildPhase = ''
              gcc nob.c -o nob
              ./nob
            '';
            installPhase = ''
              mkdir -p $out/bin
              cp zellij-sessionizer $out/bin/zellij-sessionizer
              wrapProgram $out/bin/zellij-sessionizer \
              --prefix PATH : ${pkgs.fzf}/bin  \
              --prefix PATH : ${pkgs.zellij}/bin
            '';
          };
        in build;
      bash = pkgs.writeShellApplication {
        name = pname;
        text = builtins.readFile ./zellij-sessionizer.sh ;
        runtimeInputs = with pkgs; [ fzf zellij ];
      };
    });

    devShells = forAllSystems ({pkgs, system}: {
      default = pkgs.mkShell {
        packages = with pkgs; [ fzf zellij ];
        shellHook = ''
          eval (opam env)
        '';
      };
    });
  };
}
