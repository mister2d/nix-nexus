import os
import re
import sys

def get_ns_and_name(path):
    ns = "nixos"
    if path.endswith("home.nix") or path.endswith("-home.nix") or "modules/user" in path:
        ns = "homeManager"
        
    name = path.replace('.nix', '').replace('/', '-')
    if name.startswith("modules-"): name = name[8:]
    elif name.startswith("hosts-"): name = name[6:]
    elif name.startswith("profiles-"): name = name[9:]
    
    return ns, name

def process_file(path):
    if "modules/flake" in path: return
    if "site-config.nix" in path: return
    if "vault-secrets.nix" in path: return
    if not path.endswith(".nix"): return
    if not os.path.isfile(path): return

    with open(path, 'r') as f:
        content = f.read()

    if "flake.modules." in content:
        return

    # Match header
    header_pattern = re.compile(r"^\s*\{[^}]*\}\s*:\s*", re.MULTILINE)
    match = header_pattern.search(content)

    if match and match.start() == 0:
        body = content[match.end():].strip()
    else:
        body = content.strip()

    ns, name = get_ns_and_name(path)

    new_content = f"""{{ inputs, ... }}: {{
  flake.modules.{ns}.{name} = {{ config, lib, pkgs, ... }} @ args:
    let
      self = inputs.self;
    in
{body}
}}
"""
    with open(path, 'w') as f:
        f.write(new_content)

for root, _, files in os.walk("modules"):
    for file in files:
        if file.endswith(".nix"):
            process_file(os.path.join(root, file))

for root, _, files in os.walk("hosts"):
    for file in files:
        if file.endswith(".nix"):
            process_file(os.path.join(root, file))

for root, _, files in os.walk("profiles"):
    for file in files:
        if file.endswith(".nix"):
            process_file(os.path.join(root, file))

print("Done processing files.")
