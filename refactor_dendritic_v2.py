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
    
    # Special case for Home Manager modules in desktop/hardware
    if "-home.nix" in path:
        ns = "homeManager"
        
    name_parts = []
    # Use path segments for name, e.g. modules/core/boot.nix -> core-boot
    for p in parts:
        if p in ["modules", "profiles", "hosts"]: continue
        name_parts.append(p.replace(".nix", ""))
    
    name = "-".join(name_parts)
    if name == "default":
        name = parts[-2]
    
    return ns, name

def process_file(path):
    if "modules/flake" in path: return
    if "refactor_dendritic" in path: return
    
    with open(path, 'r') as f: content = f.read()
    
    ns, name = get_ns_and_name(path)
    
    # 1. Ensure outer wrapper
    if "flake.modules" not in content:
        # If it's a plain Nix file, wrap it
        # Extract original args
        header_match = re.match(r"^\s*\{([^}]*)\}\s*:", content)
        orig_args = header_match.group(1) if header_match else ""
        used_args = ["pkgs", "lib", "config"]
        for a in ["pkgs", "lib", "config", "modulesPath"]:
            if a in orig_args and a not in used_args: used_args.append(a)
        
        body = content[header_match.end():].strip() if header_match else content.strip()
        
        # Determine if it's already an aggregator (contains imports)
        has_imports = "imports =" in body
        
        new_content = f"""{{ inputs, ... }}:
{{
  flake.modules.{ns}.{name} = args:
    let
      inherit (args) {" ".join(used_args)};
      dendriticModules = inputs.self.modules;
    in
    {body}
}}
"""
        with open(path, 'w') as f: f.write(new_content)
    else:
        # It's already partially converted, ensure it uses args:
        pattern = rf"flake\.modules\.{ns}\.{name}\s*=\s*(.*?):"
        match = re.search(pattern, content, re.DOTALL)
        if match:
            inner_args_str = match.group(1).strip()
            if inner_args_str != "args":
                # Convert Pattern to args:
                # (This is harder to do correctly with regex, but I'll try simple case)
                if inner_args_str.startswith("{") and inner_args_str.endswith("}"):
                    args = [a.strip() for a in inner_args_str[1:-1].split(",") if a.strip() and a.strip() != "..."]
                    clean_args = [a.split("?")[0].strip() if "?" in a else a for a in args]
                    inherit_line = f"inherit (args) {' '.join(clean_args)};"
                    rest = content[match.end():]
                    body_start_match = re.search(r"\s*(\{|\blet\b|\brec\b\s*\{)", rest)
                    if body_start_match:
                        body_start_pos = match.end() + body_start_match.start()
                        body_content = content[body_start_pos:].strip()
                        new_header = f"flake.modules.{ns}.{name} = args:\n    let\n      {inherit_line}\n      dendriticModules = inputs.self.modules;\n    in\n    "
                        new_content = content[:match.start()] + new_header + body_content
                        with open(path, 'w') as f: f.write(new_content)

if __name__ == '__main__':
    for p in sys.argv[1:]: process_file(p)
