# akeyless backend — translates unified secret declarations to akeyless-nix options.
#
# Requires the akeyless-nix module to be imported alongside blackmatter-secrets
# so that the akeyless.* option namespace exists. Without it, NixOS will reject
# the definitions even when mkIf condition is false.
{ config, lib, ... }:
let
  cfg = config.blackmatter.components.secrets;
  slib = import ../lib.nix { inherit lib; };
  akeylessEnabled = cfg.enable && cfg.backend == "akeyless";
  prefix = cfg.akeyless.pathPrefix;

  vaultPath = name: "${prefix}/${name}";
in {
  config = lib.mkIf akeylessEnabled {
    akeyless.enable = true;

    akeyless.package = lib.mkIf (cfg.akeyless.package != null) cfg.akeyless.package;
    akeyless.defaultSecretsMountPoint = lib.mkIf (cfg.akeyless.defaultSecretsMountPoint != "") cfg.akeyless.defaultSecretsMountPoint;
    akeyless.defaultSymlinkPath = lib.mkIf (cfg.akeyless.defaultSymlinkPath != "") cfg.akeyless.defaultSymlinkPath;
    akeyless.keepGenerations = lib.mkIf (cfg.akeyless.keepGenerations != null) cfg.akeyless.keepGenerations;
    akeyless.ignorePasswd = lib.mkIf (cfg.akeyless.ignorePasswd != null) cfg.akeyless.ignorePasswd;
    akeyless.templateEngine = lib.mkDefault cfg.akeyless.templateEngine;

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
    ) cfg.effectiveSecrets;

    akeyless.templates = lib.mapAttrs' (name: tmpl:
      lib.nameValuePair name ({
        inherit (tmpl) mode;
        content = slib.replaceAllPlaceholders {
          inherit cfg;
          backendPlaceholders = lib.mapAttrs (sName: _:
            config.akeyless.placeholder.${vaultPath sName} or ""
          ) cfg.secrets;
          content = slib.effectiveContent tmpl;
        };
      }
      // lib.optionalAttrs (tmpl.path != "") { inherit (tmpl) path; }
      // lib.optionalAttrs (tmpl.owner != "") { inherit (tmpl) owner; }
      // lib.optionalAttrs (tmpl.group != "") { inherit (tmpl) group; }
      // lib.optionalAttrs (tmpl.uid != null) { inherit (tmpl) uid; }
      // lib.optionalAttrs (tmpl.gid != null) { inherit (tmpl) gid; }
      )
    ) cfg.effectiveTemplates;
  };
}
