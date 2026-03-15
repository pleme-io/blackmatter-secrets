{
  description = "blackmatter-secrets — unified secret management abstraction (sops + akeyless backends)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
  let
    lib = nixpkgs.lib;
  in {
    homeManagerModules.default = import ./module;
    # Darwin and NixOS modules are the same — backends handle platform differences
    darwinModules.default = import ./module;
    nixosModules.default = import ./module;
  };
}
