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
    return ns, name

def process_file(path):
    if "modules/flake" in path: return
    if "refactor" in path: return
    if "site-config.nix" in path: return
    
    with open(path, 'r') as f: content = f.read()
    ns, name = get_ns_and_name(path)
    
    # 1. Clean pattern matching header
    header_match = re.match(r"^\s*\{([^}]*)\}\s*:", content)
    used_args = ["pkgs", "lib", "config"]
    if header_match:
        orig_args = header_match.group(1)
        for a in ["pkgs", "lib", "config", "modulesPath"]:
            if a in orig_args and a not in used_args: used_args.append(a)
        body = content[header_match.end():].strip()
    else:
        header_match = re.match(r"^\s*_\s*:", content)
        if header_match:
            body = content[header_match.end():].strip()
        else:
            body = content.strip()
    
    inherit_line = f"inherit (args) {' '.join(used_args)} dendriticModules;"
    
    new_content = f"""{{ inputs, ... }}:
{{
  flake.modules.{ns}.{name} = args:
    let
      {inherit_line}
    in
    {body};
}}
"""
    with open(path, 'w') as f: f.write(new_content)

if __name__ == '__main__':
    for p in sys.argv[1:]: process_file(p)
