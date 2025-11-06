{
  inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };
  outputs = {nixpkgs, ...}:
  let

    forAllSystems = function:
      nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ] (system: function nixpkgs.legacyPackages.${system});
  in
  {
    packages = forAllSystems (pkgs: {
      bash = pkgs.writeShellApplication {
        name = "zellij-sessionizer";
        text = builtins.readFile ./zellij-sessionizer.sh ;
        runtimeInputs = with pkgs; [ fzf zellij ];
      };
    });
  };
}
