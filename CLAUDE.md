# blackmatter-secrets

Unified secret management abstraction for Nix. Declare secrets once,
choose your backend — currently supports `sops` and `akeyless`,
extensible to any future backend.

## Why

Without this, you're locked to a specific backend's module interface:

```nix
# sops-nix style
sops.secrets."github/token" = { path = "..."; mode = "0600"; };

# akeyless-nix style
akeyless.secrets."/pleme/github/token" = { path = "..."; mode = "0600"; };
```

Different option names, different key formats, different template systems.
Migration means rewriting every declaration.

With blackmatter-secrets:

```nix
blackmatter.components.secrets = {
  enable = true;
  backend = "akeyless";  # flip to "sops" and everything still works

  secrets."github/token" = {
    path = "${homeDir}/.config/github/token";
    mode = "0600";
  };

  templates."kubeconfig" = {
    path = "${homeDir}/.kube/credentials";
    content = ''
      token: ${config.blackmatter.components.secrets.placeholder."k8s/token"}
    '';
  };
};
```

## Architecture

```
blackmatter.components.secrets (unified interface)
  │
  ├─ backend = "sops"
  │    → translates to sops.secrets + sops.templates
  │    → key mapping: "github/token" → sops key "github/token"
  │    → placeholder: sops.placeholder
  │
  ├─ backend = "akeyless"
  │    → translates to akeyless.secrets + akeyless.templates
  │    → key mapping: "github/token" → akeyless path "/pleme/github/token"
  │    → placeholder: akeyless.placeholder
  │
  └─ backend = "custom" (future)
       → implement the backend interface
```

## Key Design

### Secret Names are Backend-Agnostic

You declare `"github/token"`. The backend translates:
- sops: looks up key `"github/token"` in the sops file
- akeyless: fetches path `"/{prefix}/github/token"` from vault

### Backend Configuration

Each backend has its own config section:

```nix
blackmatter.components.secrets = {
  backend = "akeyless";

  # Backend-specific settings
  akeyless = {
    pathPrefix = "/pleme";  # prepended to all secret names
  };

  sops = {
    defaultSopsFile = ../../../secrets.yaml;
  };
};
```

### Placeholders for Templates

```nix
config.blackmatter.components.secrets.placeholder."github/token"
```

Returns the appropriate backend-specific placeholder string.

## Module Exports

```nix
{
  homeManagerModules.default = ./module/home-manager.nix;
  # Darwin and NixOS inherit from HM (backends handle platform differences)
}
```

## Migration Path

1. Wrap existing sops declarations with blackmatter-secrets (backend = "sops")
2. Verify identical behavior
3. Create Akeyless secrets matching the same names
4. Flip backend to "akeyless"
5. Remove sops-nix when all secrets migrated
