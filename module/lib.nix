# Shared definitions for blackmatter-secrets.
#
# Backend-agnostic secret/template submodule types, helpers, and ergonomic
# functions for clean declarative interfaces.
{ lib }:

rec {
  # ── Backend types ──────────────────────────────────────────────────
  backendType = lib.types.enum [ "sops" "akeyless" ];

  # ── Secret submodule ───────────────────────────────────────────────
  secretSubmodule = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Target file path. Empty = backend auto-generates.";
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "0600";
        description = "File permission mode (octal).";
      };
      owner = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "File owner name. Empty = backend default. NixOS/darwin + akeyless.";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "File group name. Empty = backend default. NixOS/darwin + akeyless.";
      };
      uid = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "File owner UID. Null = use owner name. sops NixOS/darwin + akeyless.";
      };
      gid = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "File group GID. Null = use group name. sops NixOS/darwin + akeyless.";
      };
      neededForUsers = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Decrypt before user creation. NixOS only (both backends).";
      };
      restartUnits = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Systemd units to restart on change. NixOS only (both backends).";
      };
      reloadUnits = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Systemd units to reload on change. NixOS only (both backends).";
      };

      # ── sops-specific per-secret options ───────────────────────────
      sopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Per-secret SOPS file override. Null = use defaultSopsFile. sops backend only.";
      };
      key = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Key to look up in the sops file. Empty = use the secret's attr name.
          Set to "" for whole-file secrets (binary format). sops backend only.
        '';
      };
      format = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Per-secret format override (yaml/json/binary/dotenv/ini). Empty = use defaultSopsFormat. sops backend only.";
      };
    };
  };

  # ── Template submodule ─────────────────────────────────────────────
  templateSubmodule = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Target file path. Empty = backend auto-generates.";
      };
      content = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Template content with placeholder substitution.";
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
        description = "File owner UID. sops NixOS/darwin + akeyless.";
      };
      gid = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "File group GID. sops NixOS/darwin + akeyless.";
      };
      restartUnits = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Systemd units to restart on change. sops NixOS only.";
      };
      reloadUnits = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Systemd units to reload on change. sops NixOS only.";
      };
    };
  };

  # ── Ergonomic helpers ──────────────────────────────────────────────

  mkHomePath = homeDir: name: "${homeDir}/.config/${name}";
  mkNixosPath = name:
    "/run/secrets/${lib.replaceStrings ["/"] ["-"] name}";

  mkSecrets = homeDir: names:
    lib.listToAttrs (map (name: {
      inherit name;
      value = { path = mkHomePath homeDir name; };
    }) names);

  mkSecretsWithPaths = pathMap:
    lib.mapAttrs (name: path: { inherit path; }) pathMap;

  # ── Template helpers ──────────────────────────────────────────────

  effectiveContent = tmpl:
    if tmpl.file != null then builtins.readFile tmpl.file else tmpl.content;

  replaceAllPlaceholders = { cfg, backendPlaceholders, content }:
    lib.foldlAttrs (acc: sName: _:
      builtins.replaceStrings
        [ (cfg.placeholder.${sName} or "") ]
        [ (backendPlaceholders.${sName} or "") ]
        acc
    ) content cfg.secrets;
}
