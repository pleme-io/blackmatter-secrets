# Shared definitions for blackmatter-secrets.
#
# Backend-agnostic secret/template submodule types, helpers, and ergonomic
# functions for clean declarative interfaces.
{ lib }:

rec {
  # ── Backend types ──────────────────────────────────────────────────
  backendType = lib.types.enum [ "sops" "akeyless" ];

  # ── Secret submodule ───────────────────────────────────────────────
  # Accepts either a full attrset or just `{}` for all defaults.
  # Default mode is 0600 (read/write owner) — the common case for secrets.
  secretSubmodule = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Target file path. If empty, auto-generated from secret name:
          "github/ghcr-token" → ~/.config/github/ghcr-token (HM)
          "github/ghcr-token" → /run/secrets/github-ghcr-token (NixOS)
        '';
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "0600";
        description = "File permission mode (octal). Default: 0600 (owner read/write).";
      };
      owner = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "File owner (empty = current user / root on NixOS).";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "File group (empty = current group / root on NixOS).";
      };
      uid = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "File owner UID (takes precedence over owner name). akeyless backend only.";
      };
      gid = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "File group GID (takes precedence over group name). akeyless backend only.";
      };
      neededForUsers = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Decrypt before user creation (NixOS only, akeyless + sops).";
      };
      restartUnits = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Systemd units to restart when this secret changes.";
      };
      reloadUnits = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Systemd units to reload when this secret changes.";
      };
      sopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Per-secret SOPS file override (sops backend only). Null = use defaultSopsFile.";
      };
    };
  };

  # ── Template submodule ─────────────────────────────────────────────
  templateSubmodule = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Target file path for rendered template. Empty = backend auto-generates.";
      };
      content = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Template content with placeholder substitution.
          Use `config.blackmatter.components.secrets.placeholder."name"` to inject secrets.
        '';
      };
      file = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Template file (read at eval time, takes precedence over content).";
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "0600";
      };
      owner = lib.mkOption { type = lib.types.str; default = ""; };
      group = lib.mkOption { type = lib.types.str; default = ""; };
      uid = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "File owner UID (akeyless backend only).";
      };
      gid = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "File group GID (akeyless backend only).";
      };
    };
  };

  # ── Ergonomic helpers ──────────────────────────────────────────────

  # Auto-generate file path from secret name for home-manager.
  # "github/ghcr-token" → "${homeDir}/.config/github/ghcr-token"
  mkHomePath = homeDir: name: "${homeDir}/.config/${name}";

  # Auto-generate file path from secret name for NixOS.
  # "github/ghcr-token" → "/run/secrets/github-ghcr-token"
  mkNixosPath = name:
    "/run/secrets/${lib.replaceStrings ["/"] ["-"] name}";

  # ── Template helpers ──────────────────────────────────────────────

  # Resolve template content: file takes precedence over inline content.
  effectiveContent = tmpl:
    if tmpl.file != null then builtins.readFile tmpl.file else tmpl.content;

  # Replace unified placeholders with backend-specific ones.
  # backendPlaceholders: attrset mapping secret name → backend placeholder string
  replaceAllPlaceholders = { cfg, backendPlaceholders, content }:
    lib.foldlAttrs (acc: sName: _:
      builtins.replaceStrings
        [ (cfg.placeholder.${sName} or "") ]
        [ (backendPlaceholders.${sName} or "") ]
        acc
    ) content cfg.secrets;

  # Shorthand: declare a secret that writes to ~/.config/{name}
  # Usage: secrets = mkSecrets homeDir [ "github/token" "attic/token" "db/password" ];
  mkSecrets = homeDir: names:
    lib.listToAttrs (map (name: {
      inherit name;
      value = { path = mkHomePath homeDir name; };
    }) names);

  # Shorthand: declare secrets with custom paths
  # Usage: secrets = mkSecretsWithPaths { "github/token" = "~/.config/github/token"; };
  mkSecretsWithPaths = pathMap:
    lib.mapAttrs (name: path: { inherit path; }) pathMap;
}
