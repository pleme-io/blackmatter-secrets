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

    # Map unified secrets → akeyless.secrets (with path prefix)
    # Only include optional fields when they have non-default values.
    akeyless.secrets = lib.mapAttrs' (name: secret:
      lib.nameValuePair (vaultPath name) ({
        inherit (secret) path mode;
      }
      // lib.optionalAttrs (secret.owner != "") { inherit (secret) owner; }
      // lib.optionalAttrs (secret.group != "") { inherit (secret) group; }
      // lib.optionalAttrs (secret.restartUnits != []) { inherit (secret) restartUnits; }
      // lib.optionalAttrs (secret.reloadUnits != []) { inherit (secret) reloadUnits; }
      )
    ) cfg.secrets;

    # Map unified templates → akeyless.templates
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
        inherit (tmpl) path mode;
        content = replaced;
      }
      // lib.optionalAttrs (tmpl.owner != "") { inherit (tmpl) owner; }
      // lib.optionalAttrs (tmpl.group != "") { inherit (tmpl) group; }
      )
    ) cfg.templates;
  };
}
