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

def clean_body(content):
    # Strip dendritic wrapper if exists
    # Find the first '{' that corresponds to the inner body
    # This is tricky, I'll try to find the start of the NixOS module: { pkgs, ... }: or { ... }:
    
    # Actually, I'll just use a simpler approach:
    # If the file contains 'flake.modules', find the first '{' after 'in' or '='.
    match = re.search(r"flake\.modules\.[a-zA-Z0-9._-]+\s*=\s*(.*?):", content, re.DOTALL)
    if match:
        rest = content[match.end():]
        # Find the first '{' or 'let'
        body_start = re.search(r"\s*(\{|\blet\b)", rest)
        if body_start:
            body = rest[body_start.start():].strip()
            # Remove trailing '}; }' or '}'
            body = re.sub(r"\s*};\s*}\s*$", "", body)
            return body
            
    # If it's the { inputs, ... }: args: pattern
    match = re.match(r"^\s*\{ inputs, \.\.\. \}:\s*args\s*:", content)
    if match:
        rest = content[match.end():]
        body_start = re.search(r"\s*(\{|\blet\b)", rest)
        if body_start:
            body = rest[body_start.start():].strip()
            return body

    return content

def process_file(path):
    if "modules/flake" in path: return
    if "refactor" in path: return
    
    with open(path, 'r') as f: content = f.read()
    ns, name = get_ns_and_name(path)
    
    # 1. Clean body (strip pattern matching header too)
    body = clean_body(content)
    header_match = re.match(r"^\s*\{[^}]*\}\s*:", body)
    if not header_match: header_match = re.match(r"^\s*_\s*:", body)
    if header_match: body = body[header_match.end():].strip()
    
    # Final Template
    new_content = f"""{{ inputs, ... }}:
{{
  flake.modules.{ns}.{name} = args: with args;
    {body};
}}
"""
    with open(path, 'w') as f: f.write(new_content)

if __name__ == '__main__':
    for p in sys.argv[1:]: process_file(p)
