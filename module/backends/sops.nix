# sops backend — translates unified secret declarations to sops-nix options.
{ config, lib, ... }:
let
  cfg = config.blackmatter.components.secrets;
  slib = import ../lib.nix { inherit lib; };
  sopsEnabled = cfg.enable && cfg.backend == "sops";
in {
  config = lib.mkIf sopsEnabled {
    # ── Map effective secrets → sops.secrets ─────────────────────────
    # Uses cfg.effectiveSecrets (defaults already applied by default.nix).
    sops.secrets = lib.mapAttrs' (name: secret:
      lib.nameValuePair name ({
        inherit (secret) mode;
      }
      // lib.optionalAttrs (secret.path != "") { inherit (secret) path; }
      // lib.optionalAttrs (secret.owner != "") { inherit (secret) owner; }
      // lib.optionalAttrs (secret.group != "") { inherit (secret) group; }
      // lib.optionalAttrs (secret.uid != null) { inherit (secret) uid; }
      // lib.optionalAttrs (secret.gid != null) { inherit (secret) gid; }
      // lib.optionalAttrs secret.neededForUsers { inherit (secret) neededForUsers; }
      // lib.optionalAttrs (secret.restartUnits != []) { inherit (secret) restartUnits; }
      // lib.optionalAttrs (secret.reloadUnits != []) { inherit (secret) reloadUnits; }
      // lib.optionalAttrs (secret.sopsFile != null) { inherit (secret) sopsFile; }
      // lib.optionalAttrs (secret.key != "") { inherit (secret) key; }
      // lib.optionalAttrs (secret.format != "") { inherit (secret) format; }
      )
    ) cfg.effectiveSecrets;

    # ── Map effective templates → sops.templates ──────────────────────
    sops.templates = lib.mapAttrs' (name: tmpl:
      lib.nameValuePair name ({
        inherit (tmpl) mode;
        content = slib.replaceAllPlaceholders {
          inherit cfg;
          backendPlaceholders = config.sops.placeholder;
          content = slib.effectiveContent tmpl;
        };
      }
      // lib.optionalAttrs (tmpl.path != "") { inherit (tmpl) path; }
      // lib.optionalAttrs (tmpl.owner != "") { inherit (tmpl) owner; }
      // lib.optionalAttrs (tmpl.group != "") { inherit (tmpl) group; }
      // lib.optionalAttrs (tmpl.uid != null) { inherit (tmpl) uid; }
      // lib.optionalAttrs (tmpl.gid != null) { inherit (tmpl) gid; }
      // lib.optionalAttrs (tmpl.restartUnits != []) { inherit (tmpl) restartUnits; }
      // lib.optionalAttrs (tmpl.reloadUnits != []) { inherit (tmpl) reloadUnits; }
      )
    ) cfg.effectiveTemplates;

    # ── sops top-level config passthrough ─────────────────────────────
    sops.defaultSopsFile = lib.mkIf (cfg.sops.defaultSopsFile != null) cfg.sops.defaultSopsFile;
    sops.defaultSopsFormat = lib.mkDefault cfg.sops.defaultSopsFormat;
    sops.defaultSopsKey = lib.mkIf (cfg.sops.defaultSopsKey != null) cfg.sops.defaultSopsKey;
    sops.validateSopsFiles = lib.mkIf (cfg.sops.validateSopsFiles != null) cfg.sops.validateSopsFiles;
    sops.keepGenerations = lib.mkIf (cfg.sops.keepGenerations != null) cfg.sops.keepGenerations;
    sops.log = lib.mkIf (cfg.sops.log != null) cfg.sops.log;
    sops.environment = lib.mkIf (cfg.sops.environment != {}) cfg.sops.environment;
    sops.package = lib.mkIf (cfg.sops.package != null) cfg.sops.package;

    # ── age config passthrough ────────────────────────────────────────
    sops.age.keyFile = lib.mkIf (cfg.sops.age.keyFile != null) cfg.sops.age.keyFile;
    sops.age.sshKeyPaths = lib.mkIf (cfg.sops.age.sshKeyPaths != null) cfg.sops.age.sshKeyPaths;
    sops.age.generateKey = lib.mkIf (cfg.sops.age.generateKey != null) cfg.sops.age.generateKey;

    # ── gnupg config passthrough ──────────────────────────────────────
    sops.gnupg.home = lib.mkIf (cfg.sops.gnupg.home != null) cfg.sops.gnupg.home;
    sops.gnupg.sshKeyPaths = lib.mkIf (cfg.sops.gnupg.sshKeyPaths != null) cfg.sops.gnupg.sshKeyPaths;

    # ── HM-only config passthrough ────────────────────────────────────
    sops.defaultSymlinkPath = lib.mkIf (cfg.sops.defaultSymlinkPath != "") cfg.sops.defaultSymlinkPath;
    sops.defaultSecretsMountPoint = lib.mkIf (cfg.sops.defaultSecretsMountPoint != "") cfg.sops.defaultSecretsMountPoint;
  };
}
