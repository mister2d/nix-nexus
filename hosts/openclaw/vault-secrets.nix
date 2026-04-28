{
  pkgs,
  ...
}:
let
  certDir = "/run/certs";
  secretDir = "/run/secrets";
  persistentSecretDir = "/var/lib/secrets";
  vaultAddr = "https://vault.service.consul:8200";

  openclawPath = "kv-v2/data/infrastructure/tailscale";
  openclawMatrixPath = "kv-v2/data/infrastructure/openclaw/matrix";
  openclawConfigPath = "kv-v2/data/infrastructure/openclaw/config";
  matrixConfigPath = "kv-v2/data/infrastructure/matrix/avina/config";
  certDomain = "novuscotia.com";
  kvPath = "kv-v2/data/letsencrypt/certificates/live/${certDomain}";

  # Vault Agent rendering template for Tailscale auth key
  # Use printf "%s" to ensure no trailing newline, which causes "invalid key" errors.
  tailscaleKeyTmpl = pkgs.writeText "tailscale-key.ctmpl" ''
    {{ with secret "${openclawPath}" -}}
    {{ .Data.data.matrix_auth_key | printf "%s" -}}
    {{- end }}
  '';

  # OpenClaw Environment File:
  # Renders Vault secrets as env vars loaded by the openclaw-gateway systemd user unit.
  # openclaw.json references these via { "source": "env", "provider": "default", "id": "VAR" }.
  openclawEnvTmpl = pkgs.writeText "openclaw.env.ctmpl" ''
    {{ with $mc := secret "${matrixConfigPath}" -}}
    {{ with $om := secret "${openclawMatrixPath}" -}}
    {{ with $oc := secret "${openclawConfigPath}" -}}
    OPENCLAW_GATEWAY_TOKEN={{ $oc.Data.data.gateway_token }}
    OPENCLAW_MATRIX_ACCESS_TOKEN={{ $om.Data.data.access_token }}
    OPENCLAW_MATRIX_HOMESERVER=https://{{ $mc.Data.data.matrix_domain }}
    OPENCLAW_MATRIX_AUTO_JOIN_ROOM={{ $om.Data.data.initial_auto_join }}:{{ $mc.Data.data.matrix_domain }}
    OPENCLAW_GOPLACES_API_KEY={{ $oc.Data.data.go_places_api_key }}
    HA_MCP_SECRET_URL={{ $oc.Data.data.ha_mcp_secret_url }}
    {{- end }}
    {{- end }}
    {{- end }}
  '';

  # HAProxy Wildcard Certificate:
  # Renders fullchain + privkey concatenated for HAProxy.
  haproxyTmpl = pkgs.writeText "haproxy-cert.ctmpl" ''
    {{ with secret "${kvPath}" }}
    {{ .Data.data.fullchain }}{{ .Data.data.privkey }}
    {{ end }}
  '';

  # OpenClaw Configuration File:
  # Renders the full openclaw.json with secrets injected directly as strings.
  # This bypasses the need for SecretRefs in fields where they are not supported (like MCP URL).
  openclawJsonTmpl = pkgs.writeText "openclaw.json.ctmpl" ''
    {{ with $mc := secret "${matrixConfigPath}" -}}
    {{ with $om := secret "${openclawMatrixPath}" -}}
    {{ with $oc := secret "${openclawConfigPath}" -}}
    {
      "agents": {
        "defaults": {
          "workspace": "/home/groot/.openclaw/workspace",
          "timeoutSeconds": 1800,
          "heartbeat": {
            "every": "0m"
          },
          "model": {
            "primary": "custom-glyph-llama-searobin-ts-net-8443/qwen3.6-35b-a3b-coding-agent-128k"
          },
          "models": {
            "custom-glyph-llama-searobin-ts-net-8443/qwen3.5-4b-uncensored-agentic-128k": {
              "alias": "qwen3.5-4b-uncensored-agentic-128k"
            },
            "custom-glyph-llama-searobin-ts-net-8443/qwen3.5-9b-q8-agentic-128k": {
              "alias": "qwen3.5-9b-q8-agentic-128k"
            },
            "custom-glyph-llama-searobin-ts-net-8443/gemma4-e4b-agentic-128k": {
              "alias": "gemma4-e4b-agentic-128k"
            }
          }
        },
        "list": [
          {
            "id": "main",
            "tools": {
              "deny": [
                "tts",
                "browser"
              ]
            }
          }
        ]
      },
      "gateway": {
        "mode": "local",
        "auth": {
          "mode": "token",
          "token": "{{ $oc.Data.data.gateway_token }}"
        },
        "trustedProxies": ["127.0.0.1"],
        "controlUi": {
          "allowedOrigins": [
            "http://localhost",
            "https://openclaw.novuscotia.com"
          ],
          "dangerouslyDisableDeviceAuth": false
        },
        "port": 18789,
        "bind": "loopback",
        "tailscale": {
          "mode": "off",
          "resetOnExit": false
        },
        "nodes": {
          "denyCommands": [
            "canvas.eval",
            "canvas.snapshot"
          ]
        }
      },
      "session": {
        "dmScope": "per-channel-peer"
      },
      "tools": {
        "profile": "full",
        "alsoAllow": [
          "group:filesystem",
          "group:shell",
          "group:web"
        ],
        "fs": {
          "workspaceOnly": false
        },
        "web": {
          "search": {
            "provider": "searxng",
            "enabled": true
          }
        }
      },
      "channels": {
        "matrix": {
          "enabled": true,
          "encryption": true,
          "homeserver": "https://{{ $mc.Data.data.matrix_domain }}",
          "accessToken": "{{ $om.Data.data.access_token }}",
          "groupPolicy": "none",
          "groups": [],
          "users": ["@dana:{{ $mc.Data.data.matrix_domain }}"],
          "network": { "dangerouslyAllowPrivateNetwork": true },
          "autoJoin": "all",
          "autoJoinAllowlist": ["!edi-core:{{ $mc.Data.data.matrix_domain }}"],
          "streaming": "partial",
          "blockStreaming": true,
          "dm": { "policy": "pairing" }
        }
      },
      "models": {
        "mode": "merge",
        "providers": {
          "custom-glyph-llama-searobin-ts-net-8443": {
            "baseUrl": "https://glyph.llama-searobin.ts.net:8443",
            "api": "openai-completions",
            "apiKey": "dummy",
            "models": [
              {
                "id": "qwen3.6-35b-a3b-coding-agent-128k",
                "name": "qwen36-35b-a3b-coding-agent 128k (Custom Provider)",
                "contextWindow": 131072,
                "maxTokens": 4096,
                "input": [
                  "text",
                  "image"
                ],
                "cost": {
                  "input": 0,
                  "output": 0,
                  "cacheRead": 0,
                  "cacheWrite": 0
                },
                "reasoning": false
              },
              {
                "id": "qwen3.5-4b-uncensored-agentic-128k",
                "name": "qwen3.5-4b-uncensored-agentic-128k (Custom Provider)",
                "contextWindow": 128000,
                "maxTokens": 4096,
                "input": [
                  "text",
                  "image"
                ],
                "cost": {
                  "input": 0,
                  "output": 0,
                  "cacheRead": 0,
                  "cacheWrite": 0
                },
                "reasoning": false
              },
              {
                "id": "qwen3.5-9b-q8-agentic-128k",
                "name": "qwen3.5-9b-q8-agentic-128k (Custom Provider)",
                "contextWindow": 131072,
                "maxTokens": 4096,
                "input": [
                  "text",
                  "image"
                ],
                "cost": {
                  "input": 0,
                  "output": 0,
                  "cacheRead": 0,
                  "cacheWrite": 0
                },
                "reasoning": false
              },
              {
                "id": "gemma4-e4b-agentic-128k",
                "name": "gemma4-e4b-agentic-128k (Custom Provider)",
                "contextWindow": 128000,
                "maxTokens": 4096,
                "input": [
                  "text",
                  "image"
                ],
                "cost": {
                  "input": 0,
                  "output": 0,
                  "cacheRead": 0,
                  "cacheWrite": 0
                },
                "reasoning": false
              }
            ]
          }
        }
      },
      "plugins": {
        "entries": {
          "searxng": {
            "enabled": true,
            "config": {
              "webSearch": {
                "baseUrl": "https://searxng.service.internal.novuscotia.com"
              }
            }
          },
          "matrix": {
            "enabled": true
          }
        }
      },
      "skills": {
        "load": {
          "extraDirs": ["/home/groot/.agents/skills"]
        },
        "install": {
          "nodeManager": "npm"
        },
        "entries": {
          "goplaces": {
            "apiKey": "{{ $oc.Data.data.go_places_api_key }}"
          },
          "1password": { "enabled": false },
          "apple-notes": { "enabled": false },
          "apple-reminders": { "enabled": false },
          "bear-notes": { "enabled": false },
          "bluebubbles": { "enabled": false },
          "discord": { "enabled": false },
          "eightctl": { "enabled": false },
          "notion": { "enabled": false },
          "obsidian": { "enabled": false },
          "openhue": { "enabled": false },
          "oracle": { "enabled": false },
          "ordercli": { "enabled": false },
          "peekaboo": { "enabled": false },
          "searxng": {
            "enabled": true,
            "env": {
              "SEARXNG_URL": "https://searxng.service.internal.novuscotia.com/",
              "SEARXNG_FORMAT": "json"
            }
          },
          "slack": { "enabled": false },
          "songsee": { "enabled": false },
          "sonoscli": { "enabled": false },
          "spotify-player": { "enabled": false },
          "things-mac": { "enabled": false },
          "wacli": { "enabled": false }
        }
      },
      "mcp": {
        "servers": {
          "mcp-nixos": {
            "command": "mcp-nixos",
            "transport": "stdio"
          },
          "home-assistant-mcp": {
            "url": "{{ $oc.Data.data.ha_mcp_secret_url }}",
            "transport": "streamable-http",
            "connectionTimeoutMs": 10000
          }
        }
      },
      "hooks": {
        "internal": {
          "enabled": true,
          "entries": {
            "session-memory": { "enabled": true },
            "boot-md": { "enabled": true },
            "bootstrap-extra-files": { "enabled": true },
            "command-logger": { "enabled": true }
          }
        }
      }
    }
    {{- end }}
    {{- end }}
    {{- end }}
  '';

  vaultAgentConfig = pkgs.writeText "vault-agent-openclaw.hcl" ''
    exit_after_auth = false
    pid_file = "/run/vault-agent-openclaw.pid"

    auto_auth {
      method "approle" {
        config = {
          role_id_file_path   = "${persistentSecretDir}/vault-role-id"
          secret_id_file_path = "${persistentSecretDir}/vault-secret-id"
          remove_secret_id_file_after_reading = false
        }
      }
      sink "file" {
        config = {
          path = "${secretDir}/vault-token"
          mode = 0640
        }
      }
    }

    vault {
      address = "${vaultAddr}"
    }

    template {
      source = "${tailscaleKeyTmpl}"
      destination = "${secretDir}/tailscale.key"
      perms = 0640
      group = "openclaw-secrets"
      # Restart tailscaled when the key changes
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block tailscaled.service || true'"
    }

    template {
      source = "${haproxyTmpl}"
      destination = "${certDir}/haproxy.pem"
      perms = 0640
      group = "openclaw-secrets"
      # Reload HAProxy when the cert changes
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl reload-or-restart --no-block haproxy.service || true'"
    }

    template {
      source = "${openclawEnvTmpl}"
      destination = "${secretDir}/openclaw.env"
      user = "groot"
      perms = 0400
      # Use runuser for more reliable systemd user interaction
      command = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/runuser -l groot -c \"XDG_RUNTIME_DIR=/run/user/1001 ${pkgs.systemd}/bin/systemctl --user restart openclaw-gateway.service\" || true'"
    }

    template {
      source = "${openclawJsonTmpl}"
      destination = "/home/groot/.openclaw/openclaw.json"
      user = "groot"
      perms = 0600
      # Use runuser for more reliable systemd user interaction
      command = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/runuser -l groot -c \"XDG_RUNTIME_DIR=/run/user/1001 ${pkgs.systemd}/bin/systemctl --user restart openclaw-gateway.service\" || true'"
    }
  '';
in
{
  users.groups.openclaw-secrets = { };

  systemd = {
    tmpfiles.rules = [
      "d ${certDir} 0755 root openclaw-secrets -"
      "d ${secretDir} 0750 root openclaw-secrets -"
      "d ${persistentSecretDir} 0700 root root -"
      "d /home/groot/.openclaw 0700 groot groot -"
      "d /run/openclaw 0755 groot groot -"
      "d /run/openclaw/node_modules 0755 groot groot -"
      "d /run/openclaw/node_modules/@matrix-org 0755 groot groot -"
    ];

    services = {
      vault-agent-init = {
        description = "Vault Agent: Initial Secret Rendering";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        path = [
          pkgs.glibc.bin
          pkgs.systemd
          pkgs.bash
          pkgs.util-linux
          pkgs.coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.vault}/bin/vault agent -config=${vaultAgentConfig} -exit-after-auth";
          Environment = [ "HOME=/tmp" ];
          ReadWritePaths = [
            secretDir
            certDir
            "/run"
          ];
          ReadOnlyPaths = [ persistentSecretDir ];
        };
      };

      vault-agent = {
        description = "Vault Agent: Background Secret Refresh";
        after = [ "vault-agent-init.service" ];
        requires = [ "vault-agent-init.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [
          pkgs.glibc.bin
          pkgs.systemd
          pkgs.bash
          pkgs.util-linux
          pkgs.coreutils
        ];
        serviceConfig = {
          ExecStart = "${pkgs.vault}/bin/vault agent -config=${vaultAgentConfig}";
          Restart = "on-failure";
          RestartSec = "10s";
          Environment = [ "HOME=/tmp" ];
          ReadWritePaths = [
            secretDir
            certDir
            "/run"
          ];
          ReadOnlyPaths = [ persistentSecretDir ];
        };
      };

      tailscaled = {
        after = [ "vault-agent-init.service" ];
        wants = [ "vault-agent-init.service" ];
      };

      haproxy = {
        after = [ "vault-agent-init.service" ];
        wants = [ "vault-agent-init.service" ];
      };

      # Fix the race: ensure autoconnect services wait for the Vault rendering.
      tailscaled-autoconnect = {
        after = [ "vault-agent-init.service" ];
        wants = [ "vault-agent-init.service" ];
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      tailscale-autoconnect = {
        after = [ "vault-agent-init.service" ];
        wants = [ "vault-agent-init.service" ];
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };
    };
  };
}
