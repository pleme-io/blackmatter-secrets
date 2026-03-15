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
    # Note: sops-nix home-manager module does NOT support owner/group/restartUnits/reloadUnits.
    # Only include fields that sops-nix actually defines for the current platform.
    sops.secrets = lib.mapAttrs' (name: secret:
      lib.nameValuePair name ({
        inherit (secret) path mode;
      }
      // lib.optionalAttrs (secret.owner != "") { inherit (secret) owner; }
      // lib.optionalAttrs (secret.group != "") { inherit (secret) group; }
      // lib.optionalAttrs (secret.restartUnits != []) { inherit (secret) restartUnits; }
      // lib.optionalAttrs (secret.reloadUnits != []) { inherit (secret) reloadUnits; }
      )
    ) cfg.secrets;

    # Map unified templates → sops.templates
    sops.templates = lib.mapAttrs' (name: tmpl:
      let
        raw = effectiveContent tmpl;
        replaced = lib.foldlAttrs (acc: sName: _:
          builtins.replaceStrings
            [ (cfg.placeholder.${sName} or "") ]
            [ (config.sops.placeholder.${sName} or "") ]
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

    # sops-specific backend config passthrough
    sops.defaultSopsFile = lib.mkIf (cfg.sops.defaultSopsFile != null) cfg.sops.defaultSopsFile;
    sops.defaultSopsFormat = lib.mkDefault "yaml";
  };
}
