import os
import re
import sys

def get_ns_and_name(path):
    parts = path.split('/')
    if len(parts) < 2: return "other", "unnamed"
    ns_map = {
        "modules/core": "nixos",
        "modules/desktop": "nixos",
        "modules/hardware": "nixos",
        "modules/programs": "nixos",
        "modules/services": "nixos",
        "modules/user": "homeManager",
        "profiles": "nixos",
        "hosts": "nixos"
    }
    key = None
    for k in ns_map:
        if path.startswith(k):
            key = k
            break
    
    ns = ns_map.get(key, "nixos")
    if "-home.nix" in path or "hosts" in path and "home.nix" in path: ns = "homeManager"
    
    name_parts = []
    for p in parts:
        if p in ["modules", "profiles", "hosts"]: continue
        name_parts.append(p.replace(".nix", ""))
    
    name = "-".join(name_parts)
    if name == "default": name = parts[-2]
    # Standardize names to match registry
    name_map = {
        "dank-material-shell": "desktop-dms",
        "waybar-home": "desktop-waybar",
        "sway-home": "desktop-sway",
        "niri-home": "desktop-niri",
        "kanshi-home": "hardware-thinkpad-z16-kanshi",
        "niri-hardware-home": "hardware-thinkpad-z16-niri" if "thinkpad-z16" in path else "hardware-petunia-niri",
        "sway-hardware-home": "hardware-thinkpad-z16-sway",
        "neovim-home": "user-neovim",
        "television-home": "user-television",
        "terminal-home": "user-terminal",
        "home": "user-home" if "modules/user" in path else f"home-{parts[-2]}",
        "default": f"host-{parts[-2]}" if "hosts" in path else f"profiles-{parts[-2]}"
    }
    # (Actually I'll just use the filenames as I did in my manual registry)
    return ns, name

def process_file(path):
    if "modules/flake" in path: return
    if "refactor" in path: return
    if "fix_recursion" in path: return
    if "site-config.nix" in path: return
    
    with open(path, 'r') as f: content = f.read()
    
    # Extract body correctly
    header_match = re.match(r"^\s*\{[^}]*\}\s*:", content)
    if not header_match: header_match = re.match(r"^\s*_\s*:", content)
    
    body = content[header_match.end():].strip() if header_match else content.strip()
    
    ns, name = get_ns_and_name(path)
    
    # Final Template with semicolon
    new_content = f"""{{ inputs, ... }}:
{{
  flake.modules.{ns}.{name} = args: with args;
    {body};
}}
"""
    with open(path, 'w') as f: f.write(new_content)

if __name__ == '__main__':
    for p in sys.argv[1:]: process_file(p)
