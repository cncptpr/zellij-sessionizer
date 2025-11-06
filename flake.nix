{
  inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };
  outputs = {nixpkgs}:
  let

    forAllSystems = function:
      nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ] (system: function nixpkgs.legacyPackages.${system});

  in
  {
    packages = forAllSystems (pkgs: {
      bash = pkgs.writeShellScriptBin "zellij-sessionizer" (builtins.readFile ./zellij-sessionizer.sh)
    });
  };
}
