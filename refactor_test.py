import os
import re
import sys

def get_namespace_and_name(file_path):
    basename = os.path.basename(file_path)
    is_home = "user/" in file_path or basename.endswith("-home.nix") or basename == "home.nix"
    namespace = "homeManager" if is_home else "nixos"
    
    parts = file_path.replace(".nix", "").split("/")
    if parts[0] == "modules":
        parts = parts[1:]
    
    if parts[-1] == "default":
        parts = parts[:-1]
    
    name = "-".join(parts)
    return namespace, name

def extract_body(content):
    # Try to find the dendritic wrapper pattern first
    # flake.modules.nixos.name = args: let ... in BODY;
    match = re.search(r'flake\.modules\.[^=]+ = [^:]+:[^l]*let.*?in\s+(.*)\s*;\s*}\s*;\s*}\s*$', content, re.DOTALL)
    if match:
        return match.group(1).strip()
    
    # Try a simpler variant
    match = re.search(r'flake\.modules\.[^=]+ = [^:]+:.*?in\s+(.*)\s*;\s*}\s*}\s*$', content, re.DOTALL)
    if match:
        return match.group(1).strip()

    # If it's a NixOS module function { config, ... }: { ... }
    # but not wrapped in flake.modules
    if "flake.modules" not in content:
        match = re.search(r'^\s*{[^}]+}:\s*(.*)$', content, re.DOTALL)
        if match:
            return match.group(1).strip()

    return content.strip()

template = """{{ inputs, ... }}:
{{
  flake.modules.{namespace}.{name} = args: with args;
    {body};
}}
"""

file_path = sys.argv[1]
with open(file_path, "r") as f:
    content = f.read()

namespace, name = get_namespace_and_name(file_path)
body = extract_body(content)

# Remove trailing semicolon if present
if body.endswith(";"):
    body = body[:-1].strip()

new_content = template.format(namespace=namespace, name=name, body=body)
print(new_content)
