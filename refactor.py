import os
import re

def get_nix_files(dirs):
    files = []
    for d in dirs:
        for root, _, filenames in os.walk(d):
            for f in filenames:
                if f.endswith('.nix'):
                    files.append(os.path.join(root, f))
    return [f for f in files if not f.startswith('modules/flake/') and 'hardware-configuration' not in f and 'disko' not in f and not f.endswith('lock.json')]

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Is it a host or profile?
    if 'hosts/' in filepath or 'profiles/' in filepath:
        # We will handle hosts and profiles in another pass
        return

    # Normal module
    m = re.search(r'flake\.modules\.([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)\s*=', content)
    if not m:
        return
    namespace = m.group(1)
    name = m.group(2)

    if f"# Namespace choice: {namespace}" in content and "dendriticModules = inputs.self.modules;" in content and "inherit (args) pkgs lib config;" in content:
        return

    # Extract body.
    # The assignment is `flake.modules.<ns>.<name> = <args_decl>:`
    # <args_decl> can be `args` or `{ lib, pkgs, ... }` or similar.
    # It ends with `:`
    
    # Find the `=` sign for the assignment.
    eq_idx = content.find('=', m.end() - 1)
    
    # We need to find the colon that ends the argument declaration.
    # We can match `:\n` or `:\r\n` or `:\s+` where there's a newline.
    # But be careful: if the args are just `args:`, it's right there.
    # If it's `{ ... }:`, we need to skip the braces.
    
    body_start = -1
    brace_count = 0
    for i in range(eq_idx + 1, len(content)):
        char = content[i]
        if char == '{':
            brace_count += 1
        elif char == '}':
            brace_count -= 1
        elif char == ':' and brace_count == 0:
            # Found the colon that ends the arg declaration!
            body_start = i + 1
            break

    if body_start == -1:
        print(f"Failed to parse inner args for {filepath}")
        return

    # Now the body extends until the matching closing brace of the OUTER `{ ... }`
    # Wait, the outer function is `{ ... }:\n{ flake.modules... = ... }`
    # So the very last `}` in the file closes the outer `{` which contains `flake.modules = `
    # And there might be a `}` before it that closes the `flake.modules` assignment, if it's not a single function block... wait.
    # Let's look at `modules/core/boot.nix`:
    # { inputs, ... }:
    # {
    #   flake.modules.nixos.core-boot = args: let ... in { ... };
    # }
    # So the last two non-whitespace characters are `}`. The first `}` might have a `;`.
    # Let's just strip `};\n}` or `}\n}` from the end.
    
    body_str = content[body_start:]
    body_str = body_str.strip()
    if body_str.endswith('};'):
        body_str = body_str[:-2].strip()
    elif body_str.endswith('}'):
        body_str = body_str[:-1].strip()
        if body_str.endswith(';'):
            body_str = body_str[:-1].strip()
    
    if body_str.endswith('}'):
        body_str = body_str[:-1].strip()
    
    # Actually, a safer way to get the body is to strip from the end until brace_count matches.
    pass

