import os
import re
import sys

def process_file(path):
    if "modules/flake" in path: return
    if "refactor_dendritic" in path: return
    
    with open(path, 'r') as f: content = f.read()
    
    # 1. Remove the recursive definition
    content = re.sub(r"^\s*let\s+dendriticModules\s*=\s*inputs\.self\.modules\s*;\s*in", "", content, flags=re.MULTILINE)
    content = re.sub(r"^\s*dendriticModules\s*=\s*inputs\.self\.modules\s*;", "", content, flags=re.MULTILINE)
    
    # 2. Ensure it uses args: pattern and inherits dendriticModules if used
    if "dendriticModules" in content:
        # If it's a flake.modules assignment
        pattern = r"flake\.modules\.([a-zA-Z0-9._-]+)\s*=\s*args\s*:"
        if re.search(pattern, content):
            if "inherit (args) dendriticModules" not in content:
                content = re.sub(r"(args\s*:\s*let\s+inherit\s*\(args\)\s*[^;]+)", r"\1 dendriticModules", content)
        # If it's a top-level function (host/profile)
        elif re.match(r"^\{ inputs, \.\.\. \}:\s*args\s*:", content):
             if "inherit (args) dendriticModules" not in content:
                content = re.sub(r"(args\s*:\s*let\s+inherit\s*\(args\)\s*[^;]+)", r"\1 dendriticModules", content)

    with open(path, 'w') as f: f.write(content)

if __name__ == '__main__':
    for p in sys.argv[1:]: process_file(p)
