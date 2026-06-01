import os
import re
from pathlib import Path

def get_ns_and_name(path_str):
    path = path_str
    if '-home.nix' in path or '/user/' in path or path.endswith('home.nix') or path.endswith('niri-hardware-home.nix') or path.endswith('sway-hardware-home.nix') or path.endswith('kanshi-home.nix'):
        ns = 'homeManager'
    else:
        ns = 'nixos'

    parts = path.replace('.nix', '').split('/')
    parts = parts[1:] # remove modules/ profiles/ hosts/
    if not parts:
        return ns, "unnamed"
    
    if parts[-1] == 'default':
        parts = parts[:-1]
        
    if not parts:
        parts = [path.replace('.nix', '').split('/')[0]]
        
    if parts[-1].endswith('-home'):
        parts[-1] = parts[-1][:-5]
    elif parts[-1] == 'home':
        parts = parts[:-1]

    name = '-'.join(parts)
    return ns, name

# Step 1: Collect all .nix files and their metadata
file_map = {} # abs_path -> (ns, name)
target_dirs = ['modules', 'profiles', 'hosts']
for d in target_dirs:
    for root, _, files in os.walk(d):
        for f in files:
            if f.endswith('.nix'):
                path = os.path.join(root, f)
                if path.startswith('modules/flake/'):
                    continue
                abs_path = os.path.abspath(path)
                ns, name = get_ns_and_name(path)
                file_map[abs_path] = (ns, name, path)

# Step 2: Replace imports across all .nix files (even modules/flake/)
def replace_imports(content, file_path):
    # Match imports = [ ... ]; and users.<user>.imports = [ ... ];
    # Actually, we can just replace relative paths globally if they appear in an import-like context.
    # A safer approach: find any string like `./foo.nix` or `../../foo/bar.nix`
    # and if it resolves to a known file, replace it.
    
    def repl(m):
        rel_path = m.group(1)
        abs_rel = os.path.abspath(os.path.join(os.path.dirname(file_path), rel_path))
        if abs_rel in file_map:
            ns, name, _ = file_map[abs_rel]
            return f"inputs.self.modules.{ns}.{name}"
        return m.group(0)

    # regex for relative nix path (unquoted) e.g., ./foo.nix, ../bar.nix
    new_content = re.sub(r'(?<![a-zA-Z0-9_\-])(\.\.?/[a-zA-Z0-9_/\.\-]+)', repl, content)
    return new_content

for d in target_dirs + ['flake.nix']:
    if d == 'flake.nix':
        paths = [d]
    else:
        paths = []
        for root, _, files in os.walk(d):
            for f in files:
                if f.endswith('.nix'):
                    paths.append(os.path.join(root, f))
                    
    for path in paths:
        with open(path, 'r') as f:
            content = f.read()
        
        # Avoid double-wrapping if already wrapped (like users.nix I just modified)
        if path != 'flake.nix' and not path.startswith('modules/flake/'):
            if "flake.modules." not in content:
                ns, name, _ = file_map[os.path.abspath(path)]
                content = f"{{ inputs, ... }}:\n{{\n  flake.modules.{ns}.{name} = {content.strip()}\n}}\n"
            else:
                # Need to update imports inside the inner content
                pass
                
        content = replace_imports(content, os.path.abspath(path))
        
        with open(path, 'w') as f:
            f.write(content)

# Update flake.nix
with open('flake.nix', 'r') as f:
    flake_content = f.read()
if '(inputs.import-tree ./profiles)' not in flake_content:
    flake_content = flake_content.replace(
        '(inputs.import-tree ./modules/flake)',
        '(inputs.import-tree ./modules)\n          (inputs.import-tree ./profiles)\n          (inputs.import-tree ./hosts)'
    )
with open('flake.nix', 'w') as f:
    f.write(flake_content)

print("Done")