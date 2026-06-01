import os
import re

def resolve_path(base_dir, rel_path):
    if not rel_path.startswith('.'):
        return rel_path
    
    # Handle paths without quotes
    if rel_path.startswith('./') or rel_path.startswith('../'):
        full_path = os.path.normpath(os.path.join(base_dir, rel_path))
        return full_path
    
    return rel_path

def get_module_ref(full_path):
    # remove leading path and convert to namespace and name
    rel_path = os.path.relpath(full_path, start=".")
    ns = "nixos"
    if rel_path.endswith("home.nix") or rel_path.endswith("-home.nix") or "modules/user" in rel_path:
        ns = "homeManager"
        
    name = rel_path.replace('.nix', '').replace('/', '-')
    if name.startswith("modules-"): name = name[8:]
    elif name.startswith("hosts-"): name = name[6:]
    elif name.startswith("profiles-"): name = name[9:]
    
    # special cases where we didn't wrap the file
    if "modules-flake" in name: return None
    if "site-config" in name: return None
    if "vault-secrets" in name: return None
    if not rel_path.endswith(".nix"): return None

    return f"config.flake.modules.{ns}.{name}"

def process_file(path):
    if "modules/flake" in path: return
    if not path.endswith(".nix"): return
    
    with open(path, 'r') as f:
        content = f.read()
        
    # We need to find imports arrays and replace paths with config.flake.modules.xxx
    # Since imports can be multiline: imports = [ ... ];
    
    # Let's replace any relative path that exists in the repo with its module ref
    # E.g. ../../modules/core/boot.nix -> config.flake.modules.nixos.core-boot
    
    # Simple regex to find path literals like ../../something.nix or ./something.nix
    path_pattern = re.compile(r'(\.\.?/[a-zA-Z0-9_\-\./]+(?:.nix)?)')
    
    def repl(m):
        rel_path = m.group(1)
        base_dir = os.path.dirname(path)
        full_path = resolve_path(base_dir, rel_path)
        
        # Check if it actually resolves to a file we wrapped
        if os.path.isfile(full_path) and full_path.endswith('.nix'):
            mod_ref = get_module_ref(full_path)
            if mod_ref:
                return mod_ref
        
        return m.group(0)

    new_content = path_pattern.sub(repl, content)
    
    if new_content != content:
        with open(path, 'w') as f:
            f.write(new_content)

for root, _, files in os.walk("."):
    if ".git" in root or ".refactor" in root: continue
    for file in files:
        if file.endswith(".nix"):
            process_file(os.path.join(root, file))

print("Done fixing imports.")
