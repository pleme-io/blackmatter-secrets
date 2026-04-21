{
  description = "Blackmatter Secrets — unified secret management abstraction (sops + akeyless backends)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, nixpkgs, substrate, ... }:
    (import "${substrate}/lib/blackmatter-component-flake.nix") {
      inherit self nixpkgs;
      name = "blackmatter-secrets";
      description = "Unified secret management (sops + akeyless backends). Same module on all platforms — backends handle differences.";
      modules.homeManager = ./module;
      modules.nixos = ./module;
      modules.darwin = ./module;
    };
}
