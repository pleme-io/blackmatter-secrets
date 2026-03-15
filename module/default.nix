# blackmatter-secrets — unified secret management abstraction
#
# Declare secrets once, choose your backend.
# Currently supports: sops, akeyless
#
# Usage:
#   blackmatter.components.secrets = {
#     enable = true;
#     backend = "akeyless";  # or "sops"
#     secrets."github/token" = {
#       path = "${homeDir}/.config/github/token";
#       mode = "0600";
#     };
#   };
{ config, lib, pkgs, ... }:
let
  slib = import ./lib.nix { inherit lib; };
  cfg = config.blackmatter.components.secrets;
in {
  imports = [
    ./backends/sops.nix
    ./backends/akeyless.nix
  ];

  options.blackmatter.components.secrets = {
    enable = lib.mkEnableOption "Unified secret management (sops or akeyless backend)";

    backend = lib.mkOption {
      type = slib.backendType;
      default = "sops";
      description = ''
        Secret management backend.
        "sops" — decrypt from git-committed encrypted file (offline-capable)
        "akeyless" — fetch from Akeyless cloud API (audit trail, RBAC)
      '';
    };

    secrets = lib.mkOption {
      type = lib.types.attrsOf slib.secretSubmodule;
      default = {};
      description = ''
        Secrets to manage. Keys are backend-agnostic names (e.g., "github/token").
        The backend translates these to its native key format:
          sops: key "github/token" in the sops file
          akeyless: path "/{pathPrefix}/github/token" in the vault
      '';
      example = lib.literalExpression ''
        {
          "github/token" = { path = "~/.config/github/token"; mode = "0600"; };
          "db/password" = { path = "~/.config/app/db-pass"; };
        }
      '';
    };

    templates = lib.mkOption {
      type = lib.types.attrsOf slib.templateSubmodule;
      default = {};
      description = ''
        Templates with secret placeholder substitution.
        Use config.blackmatter.components.secrets.placeholder."<name>" to reference secrets.
      '';
    };

    placeholder = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Auto-generated placeholders for template substitution. Do not set manually.";
    };

    # ── Backend-specific config ────────────────────────────────────

    # ── sops backend config ─────────────────────────────────────────
    sops = {
      defaultSopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to the SOPS-encrypted secrets file.";
      };
      defaultSopsFormat = lib.mkOption {
        type = lib.types.str;
        default = "yaml";
        description = "SOPS file format (yaml, json, binary, dotenv, ini).";
      };
    };

    # ── akeyless backend config ──────────────────────────────────────
    akeyless = {
      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/pleme";
        description = ''
          Prefix prepended to all secret names for Akeyless vault paths.
          "github/token" with prefix "/pleme" becomes "/pleme/github/token".
        '';
      };
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "The akeyless-install-secrets package. Null = use akeyless-nix default.";
      };
      defaultSecretsMountPoint = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Directory for secret generations. Empty = use akeyless-nix default.";
      };
      defaultSymlinkPath = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Symlink path for current generation. Empty = use akeyless-nix default.";
      };
      keepGenerations = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Number of secret generations to keep. Null = use akeyless-nix default (2).";
      };
      ignorePasswd = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Skip owner/group lookups (CI/dry-run). Null = use akeyless-nix default.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Generate unified placeholders — backend-agnostic
    # Each backend's module replaces these with its native placeholders in templates
    blackmatter.components.secrets.placeholder = lib.mapAttrs (name: _:
      "<BMSECRET:${builtins.hashString "sha256" name}:PLACEHOLDER>"
    ) cfg.secrets;
  };
}
