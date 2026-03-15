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

---

## Real-World Usage

The `nix` repo's `profiles/darwin-developer/home/secrets.nix` is the canonical
example. It manages ~15 secrets and ~4 templates for a macOS developer workstation.

### Full Pattern (darwin-developer)

```nix
{ config, lib, ... }: let
  homeDir = config.home.homeDirectory;
  ph = config.blackmatter.components.secrets.placeholder;
in {
  # Bootstrap credentials (always sops, never migrated)
  sops = {
    age.keyFile = lib.mkDefault "${homeDir}/.config/sops/age/keys.txt";
    defaultSopsFile = lib.mkDefault ../../../secrets.yaml;
    secrets = {
      "akeyless/account-id" = { path = "${homeDir}/.config/akeyless/account-id"; mode = "0600"; };
      "akeyless/access-id"  = { path = "${homeDir}/.config/akeyless/access-id";  mode = "0600"; };
      "akeyless/access-key" = { path = "${homeDir}/.config/akeyless/access-key"; mode = "0600"; };
    };
  };

  # Everything else goes through the unified interface
  blackmatter.components.secrets = {
    enable = true;
    backend = "sops";
    sops.defaultSopsFile = ../../../secrets.yaml;
    akeyless.pathPrefix = "/pleme";

    secrets = {
      "github/ghcr-token"   = { path = "${homeDir}/.config/github/token"; };
      "atlassian/api-token"  = { path = "${homeDir}/.config/atlassian/api-token"; };
      "atlassian/username"   = { path = "${homeDir}/.config/atlassian/username"; mode = "0644"; };
      "cid/kubernetes/plo/token" = {};  # no path = backend auto-generates
    };

    templates = {
      "kubeconfig-credentials" = {
        path = "${homeDir}/.kube/credentials";
        content = ''
          apiVersion: v1
          kind: Config
          users:
          - name: plo
            user:
              token: ${ph."cid/kubernetes/plo/token"}
        '';
      };
      "cargo-credentials" = {
        path = "${homeDir}/.cargo/credentials.toml";
        content = ''
          [registry]
          token = "${ph."crates/publish-token"}"
        '';
      };
    };
  };
}
```

### How to Add a New Secret

1. **Add to `secrets.yaml`** (in the `nix` repo):

   ```bash
   cd /path/to/nix && sops secrets.yaml
   ```

   Add your key using slash-separated naming:

   ```yaml
   myservice/api-key: ENC[AES256_GCM,data:...,type:str]
   ```

2. **Add to `secrets.nix`** (or wherever the profile declares secrets):

   ```nix
   secrets."myservice/api-key" = {
     path = "${homeDir}/.config/myservice/api-key";
     mode = "0600";  # default, can omit
   };
   ```

3. **Rebuild:**

   ```bash
   nix run .#rebuild   # darwin-rebuild switch
   ```

   sops-nix decrypts the value and writes it to the path on activation.

### How Templates Work

Templates compose multiple secrets into a single config file. The backend
substitutes placeholder tokens with real values at activation time.

**Step 1:** Declare the secrets the template needs (they must exist in `secrets`):

```nix
secrets."k8s/token" = {};
secrets."k8s/cert"  = {};
```

**Step 2:** Reference them via `placeholder` in the template content:

```nix
templates."kubeconfig" = {
  path = "${homeDir}/.kube/credentials";
  content = ''
    users:
    - name: prod
      user:
        token: ${ph."k8s/token"}
        client-certificate-data: ${ph."k8s/cert"}
  '';
};
```

**How placeholders work internally:**

1. `placeholder."k8s/token"` generates a deterministic hash token:
   `<BMSECRET:{sha256("k8s/token")}:PLACEHOLDER>`
2. This hash is embedded in the template content at Nix eval time.
3. The backend (sops.nix or akeyless.nix) replaces these hash tokens with
   the backend's native placeholder format (e.g., `config.sops.placeholder."k8s/token"`).
4. At activation time, the backend substitutes real secret values.

This indirection lets you write templates once and switch backends without changes.

### Wiring Secrets to MCP Servers (Atlassian Example)

Secrets declared through blackmatter-secrets land as files on disk. Wire them to
MCP servers or other tools by reading the file path:

```nix
# In secrets.nix
secrets."atlassian/api-token" = { path = "${homeDir}/.config/atlassian/api-token"; };
secrets."atlassian/username"  = { path = "${homeDir}/.config/atlassian/username"; mode = "0644"; };
secrets."atlassian/site-url"  = { path = "${homeDir}/.config/atlassian/site-url"; mode = "0644"; };

# In MCP server config (e.g., blackmatter-claude)
# The MCP server reads the file at the configured path:
#   api_token = "$(cat ~/.config/atlassian/api-token)"
#   site_url  = "$(cat ~/.config/atlassian/site-url)"
```

The secret file is always available after activation. Any tool that reads files
can consume it — no special integration needed.

### How to Flip Backend from sops to akeyless

**Prerequisites:**
- Akeyless account with secrets mirrored at `/pleme/{secret-name}` paths
- `akeyless-nix` flake input added to the nix repo
- Bootstrap credentials (`akeyless/account-id`, `akeyless/access-id`, `akeyless/access-key`)
  remain in raw `sops.secrets` (they bootstrap akeyless-nix itself)

**Steps:**

1. Verify all secrets exist in Akeyless under the configured `pathPrefix`:

   ```bash
   akeyless list-items --path /pleme/
   ```

2. Change one line in `secrets.nix`:

   ```nix
   blackmatter.components.secrets = {
     backend = "akeyless";  # was "sops"
     # everything else stays identical
   };
   ```

3. Rebuild. The module now generates `akeyless.secrets` + `akeyless.templates`
   instead of `sops.secrets` + `sops.templates`. All paths, modes, and template
   content remain the same.

4. Verify secrets are decrypted:

   ```bash
   cat ~/.config/github/token   # should contain the real value
   ```

**Important:** The `akeyless.pathPrefix` (default `"/pleme"`) is prepended to
every secret name. So `"github/ghcr-token"` becomes `/pleme/github/ghcr-token`
in Akeyless. Ensure your Akeyless folder structure matches.
