# blackmatter-secrets — unified secret management abstraction
#
# Declare secrets once, choose your backend.
# Currently supports: sops, akeyless
#
# Usage:
#   blackmatter.components.secrets = {
#     enable = true;
#     backend = "akeyless";  # or "sops"
#     defaults.mode = "0400";
#     defaults.owner = "root";
#     defaults.group = "root";
#     secrets."github/token" = {
#       path = "${homeDir}/.config/github/token";
#     };
#   };
{ config, lib, pkgs, ... }:
let
  slib = import ./lib.nix { inherit lib; };
  cfg = config.blackmatter.components.secrets;

  # Apply defaults to a secret: merge user-specified values over defaults.
  applySecretDefaults = name: secret: secret // {
    mode = if secret.mode != "0600" then secret.mode
           else if cfg.defaults.mode != "" then cfg.defaults.mode
           else "0600";
    owner = if secret.owner != "" then secret.owner else cfg.defaults.owner;
    group = if secret.group != "" then secret.group else cfg.defaults.group;
  };

  # Apply defaults to a template.
  applyTemplateDefaults = name: tmpl: tmpl // {
    mode = if tmpl.mode != "0600" then tmpl.mode
           else if cfg.defaults.templateMode != "" then cfg.defaults.templateMode
           else "0600";
    owner = if tmpl.owner != "" then tmpl.owner else cfg.defaults.templateOwner;
    group = if tmpl.group != "" then tmpl.group else cfg.defaults.templateGroup;
  };

  # The effective secrets/templates with defaults applied.
  effectiveSecrets = lib.mapAttrs applySecretDefaults cfg.secrets;
  effectiveTemplates = lib.mapAttrs applyTemplateDefaults cfg.templates;
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

    # ── Defaults (reduce per-secret boilerplate) ──────────────────────

    defaults = {
      mode = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Default permission mode for all secrets. Empty = 0600.";
      };
      owner = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Default owner for all secrets. Empty = backend default.";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Default group for all secrets. Empty = backend default.";
      };
      templateMode = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Default permission mode for all templates. Empty = 0600.";
      };
      templateOwner = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Default owner for all templates. Empty = backend default.";
      };
      templateGroup = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Default group for all templates. Empty = backend default.";
      };
    };

    # ── Secret and template declarations ──────────────────────────────

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

    # ── Computed outputs (read-only) ──────────────────────────────────

    placeholder = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Auto-generated placeholders for template substitution. Do not set manually.";
    };

    effectiveSecrets = lib.mkOption {
      type = lib.types.attrsOf slib.secretSubmodule;
      default = {};
      description = "Secrets with defaults applied. Read-only — used by backends.";
    };

    effectiveTemplates = lib.mkOption {
      type = lib.types.attrsOf slib.templateSubmodule;
      default = {};
      description = "Templates with defaults applied. Read-only — used by backends.";
    };

    secretNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Read-only list of declared secret names.";
    };

    templateNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Read-only list of declared template names.";
    };

    secretCount = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "Read-only count of declared secrets.";
    };

    templateCount = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "Read-only count of declared templates.";
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
      defaultSopsKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default key for all secrets. Null = use attr name. Empty string = whole file.";
      };
      validateSopsFiles = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Check sops files exist at eval time. Null = sops-nix default (true).";
      };
      keepGenerations = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Secret generations to keep (0 = no pruning). Null = sops-nix default (1).";
      };
      log = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "What to log: [\"keyImport\" \"secretChanges\"]. Null = sops-nix default (both).";
      };
      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Environment variables for sops-install-secrets.";
      };
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "sops-install-secrets package. Null = sops-nix default.";
      };
      age = {
        keyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Path to age key file. Null = sops-nix default.";
        };
        sshKeyPaths = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          default = null;
          description = "SSH key paths to convert to age keys. Null = sops-nix default.";
        };
        generateKey = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          description = "Auto-generate age key if missing. Null = sops-nix default (false).";
        };
      };
      gnupg = {
        home = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "GnuPG home directory. Null = sops-nix default.";
        };
        sshKeyPaths = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          default = null;
          description = "SSH key paths to import as GPG keys. Null = sops-nix default.";
        };
      };
      defaultSymlinkPath = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Symlink directory for secrets (HM only). Empty = sops-nix default.";
      };
      defaultSecretsMountPoint = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Generations storage directory (HM only). Empty = sops-nix default.";
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
      templateEngine = lib.mkOption {
        type = lib.types.str;
        default = "placeholder";
        description = "Template engine: placeholder (legacy hash-based) or igata (MiniJinja).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # ── Computed outputs ──────────────────────────────────────────────
    blackmatter.components.secrets.placeholder = lib.mapAttrs (name: _:
      "<BMSECRET:${builtins.hashString "sha256" name}:PLACEHOLDER>"
    ) cfg.secrets;

    blackmatter.components.secrets.effectiveSecrets = effectiveSecrets;
    blackmatter.components.secrets.effectiveTemplates = effectiveTemplates;
    blackmatter.components.secrets.secretNames = lib.attrNames cfg.secrets;
    blackmatter.components.secrets.templateNames = lib.attrNames cfg.templates;
    blackmatter.components.secrets.secretCount = lib.length (lib.attrNames cfg.secrets);
    blackmatter.components.secrets.templateCount = lib.length (lib.attrNames cfg.templates);
  };
}
