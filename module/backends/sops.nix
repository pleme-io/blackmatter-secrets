# sops backend — translates unified secret declarations to sops-nix options.
{ config, lib, ... }:
let
  cfg = config.blackmatter.components.secrets;
  sopsEnabled = cfg.enable && cfg.backend == "sops";

  # Template content: file takes precedence over inline
  effectiveContent = tmpl:
    if tmpl.file != null then builtins.readFile tmpl.file else tmpl.content;
in {
  config = lib.mkIf sopsEnabled {
    # Map unified secrets → sops.secrets
    sops.secrets = lib.mapAttrs' (name: secret:
      lib.nameValuePair name {
        inherit (secret) path mode owner group;
        # sops-specific: restartUnits/reloadUnits if available
        restartUnits = secret.restartUnits;
        reloadUnits = secret.reloadUnits;
      }
    ) cfg.secrets;

    # Map unified templates → sops.templates
    sops.templates = lib.mapAttrs' (name: tmpl:
      lib.nameValuePair name {
        inherit (tmpl) path mode owner group;
        content = let
          raw = effectiveContent tmpl;
          # Replace unified placeholders with sops placeholders
          replaced = lib.foldlAttrs (acc: sName: _:
            builtins.replaceStrings
              [ (cfg.placeholder.${sName} or "") ]
              [ (config.sops.placeholder.${sName} or "") ]
              acc
          ) raw cfg.secrets;
        in replaced;
      }
    ) cfg.templates;

    # sops-specific backend config passthrough
    sops.defaultSopsFile = lib.mkIf (cfg.sops.defaultSopsFile != null) cfg.sops.defaultSopsFile;
    sops.defaultSopsFormat = lib.mkDefault "yaml";
  };
}
