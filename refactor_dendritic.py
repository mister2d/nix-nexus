import os
import re
import sys

def process_module(content, ns, name):
    pattern = rf"flake\.modules\.{ns}\.{name}\s*=\s*(.*?):"
    match = re.search(pattern, content, re.DOTALL)
    if not match: return content
    inner_args_str = match.group(1).strip()
    if inner_args_str == "args" and "dendriticModules =" in content: return content
    if inner_args_str.startswith("{") and inner_args_str.endswith("}"):
        args = [a.strip() for a in inner_args_str[1:-1].split(",") if a.strip() and a.strip() != "..."]
        clean_args = [a.split("?")[0].strip() if "?" in a else a for a in args]
        inherit_line = f"inherit (args) {' '.join(clean_args)};"
        rest = content[match.end():]
        body_start_match = re.search(r"\s*(\{|\blet\b|\brec\b\s*\{)", rest)
        if not body_start_match: return content
        body_start_pos = match.end() + body_start_match.start()
        body_content = content[body_start_pos:].strip()
        new_header = f"flake.modules.{ns}.{name} = args:\n    let\n      {inherit_line}\n      dendriticModules = inputs.self.modules;\n    in\n    "
        return content[:match.start()] + new_header + body_content
    return content

def process_file(path):
    with open(path, 'r') as f: content = f.read()
    if "modules/flake" in path: return
    is_module = "flake.modules." in content
    if is_module:
        if not re.match(r"^\s*\{\s*inputs\s*,\s*\.\.\.\s*\}\s*:", content):
            content = re.sub(r"^\{\s*\.\.\.\s*\}\s*:", "{ inputs, ... }:", content)
            if not content.startswith("{ inputs, ... }:"): content = "{ inputs, ... }:\n" + content
        matches = re.findall(r"flake\.modules\.([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)\s*=", content)
        for ns, name in matches: content = process_module(content, ns, name)
    else:
        original_header_match = re.match(r"^\s*\{([^}]*)\}\s*:", content)
        used_args = ["pkgs", "lib", "config"]
        if original_header_match:
            orig_args = original_header_match.group(1)
            for a in ["pkgs", "lib", "config", "modulesPath"]:
                if a in orig_args and a not in used_args: used_args.append(a)
        inherit_line = f"    inherit (args) {' '.join(used_args)};\n    dendriticModules = inputs.self.modules;\n"
        new_top = "{ inputs, ... }: args:\n  let\n"
        if original_header_match:
            rest = content[original_header_match.end():].strip()
            if rest.startswith("let"):
                rest = re.sub(r"^let\s+", "", rest)
                rest = re.sub(r"^\s*dendriticModules\s*=\s*inputs\.self\.modules\s*;\s*", "", rest, flags=re.MULTILINE)
                content = new_top + inherit_line + rest
            else:
                content = new_top + inherit_line + "  in\n  " + rest
    with open(path, 'w') as f: f.write(content)

if __name__ == '__main__':
    for p in sys.argv[1:]: process_file(p)
