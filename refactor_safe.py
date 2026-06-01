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
    if "-home.nix" in path or ("hosts" in path and "home.nix" in path): ns = "homeManager"
    
    name_parts = []
    for p in parts:
        if p in ["modules", "profiles", "hosts"]: continue
        name_parts.append(p.replace(".nix", ""))
    
    name = "-".join(name_parts)
    if name == "default": name = parts[-2]
    return ns, name

def process_file(path):
    if "modules/flake" in path: return
    if "site-config.nix" in path: return
    if not path.endswith(".nix"): return
    
    with open(path, 'r') as f: content = f.read()
    
    ns, name = get_ns_and_name(path)
    
    # Strip any previous wrapper if it exists (for safety)
    # The baseline is clean, so it shouldn't have wrappers.
    # But just in case, we assume the content is the raw lambda.
    
    # Add indentation to the original content
    indented_content = "\n".join(["      " + line for line in content.split("\n")])
    
    new_content = f"""{{ inputs, ... }}:
{{
  flake.modules.{ns}.{name} = args: (
    (
{indented_content}
    ) (args // {{ inherit inputs; dendriticModules = inputs.self.modules; }})
  );
}}
"""
    with open(path, 'w') as f: f.write(new_content)

if __name__ == '__main__':
    # Find all .nix files in the provided directories
    for root_dir in sys.argv[1:]:
        for dirpath, _, filenames in os.walk(root_dir):
            for filename in filenames:
                if filename.endswith(".nix"):
                    process_file(os.path.join(dirpath, filename))
