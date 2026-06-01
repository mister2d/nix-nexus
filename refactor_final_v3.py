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
    if "-home.nix" in path: ns = "homeManager"
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
    if "fix_recursion" in path: return
    
    with open(path, 'r') as f: content = f.read()
    ns, name = get_ns_and_name(path)
    
    # Use the robust pattern
    new_content = f"""{{ inputs, ... }}:
{{
  flake.modules.{ns}.{name} = args: with args;
    let
      dendriticModules = inputs.self.modules;
    in
    {content.strip()}
}}
"""
    # Wait! I need to unwrap the existing wrapper if it exists.
    # Actually, I'll just find the REAL body.
    # A safer way is to use regex to find the inner block.
    
    # Find the FIRST '{' or 'let' that is NOT part of the wrapper.
    # This is hard.
    
    # I'll just use the baseline content!
    # No, I don't have it for all files.
    
    # I'll try to extract the body between the first and last curly braces.
    # No, that's too simple.
    
    # Actually, I'll just REVERT all changes to leaf modules and start over with a BETTER script.
    pass

if __name__ == '__main__':
    for p in sys.argv[1:]: process_file(p)
