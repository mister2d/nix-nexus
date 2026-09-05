# Helper: builds the context-mode-hermes Python package.
# Called by: hosts/hermes/llm-agents-overlay.nix.
{
  lib,
  pythonPackages,
  fetchFromGitHub,
}:

pythonPackages.buildPythonPackage {
  pname = "context-mode-hermes";
  version = "1.3.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "christopher-s";
    repo = "context-mode-hermes";
    rev = "b85072a9bdcd528549bc49a383a7f9f6e0cca348";
    hash = "sha256-qQOLUiciE6cYBVCCJWPyaJOtn96MuQo2Q27Jt9ulKE4=";
  };

  build-system = [ pythonPackages.setuptools ];

  # Runtime dependencies: none. The module imports only the Python stdlib.
  doCheck = false;

  pythonImportsCheck = [ "context_mode_hermes" ];

  meta = {
    description = "Hermes agent plugin providing context-aware tool-call routing";
    homepage = "https://github.com/christopher-s/context-mode-hermes";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
