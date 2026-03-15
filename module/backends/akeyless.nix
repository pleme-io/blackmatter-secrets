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
    akeyless.secrets = lib.mapAttrs' (name: secret:
      lib.nameValuePair (vaultPath name) {
        inherit (secret) path mode owner group;
        restartUnits = secret.restartUnits;
        reloadUnits = secret.reloadUnits;
      }
    ) cfg.secrets;

    # Map unified templates → akeyless.templates
    akeyless.templates = lib.mapAttrs' (name: tmpl:
      lib.nameValuePair name {
        inherit (tmpl) path mode owner group;
        content = let
          raw = effectiveContent tmpl;
          # Replace unified placeholders with akeyless placeholders
          replaced = lib.foldlAttrs (acc: sName: _:
            builtins.replaceStrings
              [ (cfg.placeholder.${sName} or "") ]
              [ (config.akeyless.placeholder.${vaultPath sName} or "") ]
              acc
          ) raw cfg.secrets;
        in replaced;
      }
    ) cfg.templates;
  };
}
