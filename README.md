# blackmatter-secrets

Unified secret management across sops and akeyless backends. One module, any
platform (HM/NixOS/Darwin), backend-agnostic option surface.

## Usage

```nix
blackmatter.components.secrets = {
  enable = true;
  backend = "sops";        # or "akeyless"
  secrets."github/token" = { path = "~/.config/github/token"; mode = "0400"; };
  templates."kubeconfig" = { path = "~/.kube/config"; content = ...; };
};
```

Switching backend flips `backend = "akeyless"` — declarations stay the same.
Akeyless bootstrap credentials remain in sops permanently.

## License

MIT
