# sops backend — translates unified secret declarations to sops-nix options.
{ config, lib, ... }:
let
  cfg = config.blackmatter.components.secrets;
  slib = import ../lib.nix { inherit lib; };
  sopsEnabled = cfg.enable && cfg.backend == "sops";
in {
  config = lib.mkIf sopsEnabled {
    # ── Map unified secrets → sops.secrets ────────────────────────────
    # Note: sops-nix home-manager module does NOT support owner/group/restartUnits/reloadUnits/neededForUsers.
    # NixOS module supports all of them. We conditionally include fields when non-default,
    # which is safe on both platforms (unsupported fields simply won't be set).
    sops.secrets = lib.mapAttrs' (name: secret:
      lib.nameValuePair name ({
        inherit (secret) mode;
      }
      // lib.optionalAttrs (secret.path != "") { inherit (secret) path; }
      // lib.optionalAttrs (secret.owner != "") { inherit (secret) owner; }
      // lib.optionalAttrs (secret.group != "") { inherit (secret) group; }
      // lib.optionalAttrs secret.neededForUsers { inherit (secret) neededForUsers; }
      // lib.optionalAttrs (secret.restartUnits != []) { inherit (secret) restartUnits; }
      // lib.optionalAttrs (secret.reloadUnits != []) { inherit (secret) reloadUnits; }
      // lib.optionalAttrs (secret.sopsFile != null) { inherit (secret) sopsFile; }
      )
    ) cfg.secrets;

    # ── Map unified templates → sops.templates ───────────────────────
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
      )
    ) cfg.templates;

    # ── sops-specific backend config passthrough ─────────────────────
    sops.defaultSopsFile = lib.mkIf (cfg.sops.defaultSopsFile != null) cfg.sops.defaultSopsFile;
    sops.defaultSopsFormat = lib.mkDefault cfg.sops.defaultSopsFormat;
  };
}
