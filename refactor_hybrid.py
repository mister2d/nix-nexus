import os
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
    if "hardware-configuration.nix" in path: return
    if "disko.nix" in path: return
    if "openclaude-lock.json" in path: return
    
    with open(path, 'r') as f: content = f.read()
    
    ns, name = get_ns_and_name(path)
    
    indented_content = "\n".join(["    " + line for line in content.split("\n")])
    
    new_content = f"""{{ inputs ? null, ... }}@outerArgs:
let
  inner = 
{indented_content}
  ;
  wrapper = args:
    if args ? withSystem then {{
      flake.modules.{ns}."{name}" = inner;
    }} else (
      if builtins.isFunction inner then inner args else inner
    );
in
if builtins.isFunction inner then
  {{
    __functor = self: wrapper;
    __functionArgs = builtins.functionArgs inner // {{ withSystem = true; inputs = true; }};
  }}
else
  wrapper outerArgs
"""
    with open(path, 'w') as f: f.write(new_content)
    
    with open('.refactor/module-map.tsv', 'a') as f:
        f.write(f"{path}\t{ns}.{name}\n")

if __name__ == '__main__':
    open('.refactor/module-map.tsv', 'w').close()
    for root_dir in sys.argv[1:]:
        for dirpath, _, filenames in os.walk(root_dir):
            for filename in filenames:
                if filename.endswith(".nix"):
                    process_file(os.path.join(dirpath, filename))
