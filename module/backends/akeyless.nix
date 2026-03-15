# akeyless backend — translates unified secret declarations to akeyless-nix options.
{ config, lib, ... }:
let
  cfg = config.blackmatter.components.secrets;
  akeylessEnabled = cfg.enable && cfg.backend == "akeyless";
  prefix = cfg.akeyless.pathPrefix;

  # Prepend the vault path prefix to a secret name
  # "github/token" → "/pleme/github/token"
  vaultPath = name: "${prefix}/${name}";

  # Template content: file takes precedence over inline
  effectiveContent = tmpl:
    if tmpl.file != null then builtins.readFile tmpl.file else tmpl.content;
in {
  config = lib.mkIf akeylessEnabled {
    akeyless.enable = true;

    # ── Passthrough akeyless-nix configuration ───────────────────────
    akeyless.package = lib.mkIf (cfg.akeyless.package != null) cfg.akeyless.package;
    akeyless.defaultSecretsMountPoint = lib.mkIf (cfg.akeyless.defaultSecretsMountPoint != "") cfg.akeyless.defaultSecretsMountPoint;
    akeyless.defaultSymlinkPath = lib.mkIf (cfg.akeyless.defaultSymlinkPath != "") cfg.akeyless.defaultSymlinkPath;
    akeyless.keepGenerations = lib.mkIf (cfg.akeyless.keepGenerations != null) cfg.akeyless.keepGenerations;
    akeyless.ignorePasswd = lib.mkIf (cfg.akeyless.ignorePasswd != null) cfg.akeyless.ignorePasswd;

    # ── Map unified secrets → akeyless.secrets (with path prefix) ────
    akeyless.secrets = lib.mapAttrs' (name: secret:
      lib.nameValuePair (vaultPath name) ({
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
      )
    ) cfg.secrets;

    # ── Map unified templates → akeyless.templates ───────────────────
    akeyless.templates = lib.mapAttrs' (name: tmpl:
      let
        raw = effectiveContent tmpl;
        replaced = lib.foldlAttrs (acc: sName: _:
          builtins.replaceStrings
            [ (cfg.placeholder.${sName} or "") ]
            [ (config.akeyless.placeholder.${vaultPath sName} or "") ]
            acc
        ) raw cfg.secrets;
      in
      lib.nameValuePair name ({
        inherit (tmpl) mode;
        content = replaced;
      }
      // lib.optionalAttrs (tmpl.path != "") { inherit (tmpl) path; }
      // lib.optionalAttrs (tmpl.owner != "") { inherit (tmpl) owner; }
      // lib.optionalAttrs (tmpl.group != "") { inherit (tmpl) group; }
      // lib.optionalAttrs (tmpl.uid != null) { inherit (tmpl) uid; }
      // lib.optionalAttrs (tmpl.gid != null) { inherit (tmpl) gid; }
      )
    ) cfg.templates;
  };
}
