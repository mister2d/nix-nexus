{
  lib,
  stdenv,
  python3,
  rustPlatform,
  fetchFromGitHub,
  fetchPypi,
  buildNpmPackage,
  nodejs,
  olm,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  # Native (PyO3) runtime for hermes' Relay lifecycle and shared metrics;
  # PyPI ships wheels only, so build from source with maturin.
  nemo-relay = python3.pkgs.buildPythonPackage rec {
    pname = "nemo-relay";
    version = "0.6.0";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "NVIDIA";
      repo = "NeMo-Relay";
      tag = version;
      hash = "sha256-mqI1tDl01a+FCv1FSMqvzYGuS/7hNlc99jcFiN6dRIM=";
    };

    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit src;
      name = "nemo-relay-${version}";
      hash = "sha256-KxPNGhYHmMFCSiEJomZztrc2P/knYA0It+vuurIccCQ=";
    };

    nativeBuildInputs = with rustPlatform; [
      cargoSetupHook
      maturinBuildHook
    ];

    pythonImportsCheck = [
      "nemo_relay"
      "nemo_relay._native"
    ];

    meta = with lib; {
      description = "Python bindings for the NeMo Relay agent runtime";
      homepage = "https://github.com/NVIDIA/NeMo-Relay";
      license = licenses.asl20;
      sourceProvenance = with sourceTypes; [ fromSource ];
      platforms = platforms.unix;
    };
  };

  exa-py = python3.pkgs.buildPythonPackage rec {
    pname = "exa-py";
    version = "2.10.2";
    pyproject = true;

    src = fetchPypi {
      pname = "exa_py";
      inherit version;
      hash = "sha256-94HzCxmfEQIzM4RyitrmS7Faa7yr+pfpH9cF+QrP/EU=";
    };

    build-system = with python3.pkgs; [
      poetry-core
    ];

    dependencies = with python3.pkgs; [
      httpcore
      httpx
      openai
      pydantic
      python-dotenv
      requests
      typing-extensions
    ];

    pythonImportsCheck = [ "exa_py" ];

    meta = with lib; {
      description = "Python SDK for Exa API";
      homepage = "https://github.com/exa-labs/exa-py";
      license = licenses.mit;
      sourceProvenance = with sourceTypes; [ fromSource ];
      platforms = platforms.all;
    };
  };

  fal-client = python3.pkgs.buildPythonPackage rec {
    pname = "fal-client";
    version = "0.13.1";
    pyproject = true;

    src = fetchPypi {
      pname = "fal_client";
      inherit version;
      hash = "sha256-nhwH0KYbRSqP+0jBmd5fJUPXVG8SMPYxI3BEMSfF6Tc=";
    };

    build-system = with python3.pkgs; [
      setuptools
      setuptools-scm
    ];

    dependencies = with python3.pkgs; [
      httpx
      httpx-sse
      msgpack
      websockets
    ];

    pythonImportsCheck = [ "fal_client" ];

    meta = with lib; {
      description = "Python client for fal.ai";
      homepage = "https://github.com/fal-ai/fal";
      license = licenses.asl20;
      sourceProvenance = with sourceTypes; [ fromSource ];
      platforms = platforms.all;
    };
  };

  parallel-web = python3.pkgs.buildPythonPackage rec {
    pname = "parallel-web";
    version = "0.4.2";
    pyproject = true;

    src = fetchPypi {
      pname = "parallel_web";
      inherit version;
      hash = "sha256-WZtajzh9w1x9yMgeNy6t9pWKQKys6li/Fw38ZjwAPac=";
    };

    build-system = with python3.pkgs; [
      hatchling
      hatch-fancy-pypi-readme
    ];

    # Upstream pins hatchling==1.26.3 in build-system.requires; pythonRelaxDeps
    # only touches runtime metadata, so skip the build-time pin check.
    pypaBuildFlags = [ "--skip-dependency-check" ];

    dependencies = with python3.pkgs; [
      anyio
      distro
      httpx
      pydantic
      sniffio
      typing-extensions
    ];

    pythonImportsCheck = [ "parallel" ];

    meta = with lib; {
      description = "Python SDK for Parallel Web API";
      homepage = "https://github.com/parallel-web/parallel-sdk-python";
      license = licenses.asl20;
      sourceProvenance = with sourceTypes; [ fromSource ];
      platforms = platforms.all;
    };
  };

  version = "2026.8.3";

  src = fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-agent";
    tag = "v${version}";
    hash = "sha256-S6TSGgpf37N8YgbTv70dT+LaPiiaQ4/lJV+js2hnCPk=";
  };

  # Upstream moved ui-tui/ and web/ into npm workspaces with a single root
  # package-lock.json, so both frontends must be built from the repo root.
  # `hermes --tui` runs the compiled Ink/React bundle via HERMES_TUI_DIR
  # (hermes_cli/main.py:_make_tui_argv fast-path, #4364) and
  # `hermes dashboard` serves the Vite app via HERMES_WEB_DIST.
  hermes-frontend = buildNpmPackage {
    pname = "hermes-frontend";
    inherit version src;
    npmDepsHash = "sha256-33ALD6Th++LCp8JiVO6ba27GhuP3GBuLGUuyoJg99iM=";

    # The apps/desktop workspace pulls in electron; skip its binary download
    # and all install scripts — the esbuild/vite builds below don't need them.
    # Upstream's engines.npm range excludes nixpkgs' current npm; the pin is
    # only about a CLI compat quirk unrelated to this build.
    npmFlags = [
      "--ignore-scripts"
      "--engine-strict=false"
    ];
    env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

    buildPhase = ''
      runHook preBuild
      npm run build --workspace ui-tui
      npm run build --workspace web -- --outDir "$TMPDIR/web-dist"
      runHook postBuild
    '';

    # dist/entry.js is a self-contained esbuild bundle; package.json is kept
    # so node resolves it as an ES module.
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/hermes-tui $out/share/hermes-web
      cp -r ui-tui/dist ui-tui/package.json $out/lib/hermes-tui/
      cp -r "$TMPDIR/web-dist"/. $out/share/hermes-web/
      runHook postInstall
    '';
  };

  hermesDeps =
    with python3.pkgs;
    [
      # Core
      openai
      anthropic
      python-dotenv
      fire
      httpx
      rich
      tenacity
      pathspec
      pillow
      pyyaml
      ruamel-yaml
      requests
      jinja2
      pydantic
      # Interactive CLI
      prompt-toolkit
      # Cron scheduler
      croniter
      # Process / PID management
      psutil
      # MCP
      mcp
      # Tools
      exa-py
      firecrawl-py'
      parallel-web
      fal-client
      # Text-to-speech
      edge-tts
      # Skills Hub
      pyjwt
      cryptography
      # Relay lifecycle + shared metrics
      nemo-relay
    ]
    # faster-whisper -> av SIGKILLs during import on darwin; voice is optional.
    ++ lib.optionals stdenv.hostPlatform.isLinux [ faster-whisper ]
    ++ optionalDeps.gateway
    ++ optionalDeps.misc;

  # Upstream extras only warn-and-disable at runtime when missing (#4175), so
  # ship every extra nixpkgs has. Not yet packaged: honcho, daytona, dingtalk,
  # feishu.
  # libolm is marked insecure in nixpkgs but mautrix[encryption] needs it for
  # Matrix E2EE. Same trade-off as picoclaw.
  clearedOlm = olm.overrideAttrs (old: {
    meta = old.meta // {
      knownVulnerabilities = [ ];
    };
  });

  # nixpkgs' firecrawl-py 2.8.0 builds from the firecrawl monorepo tag v2.8.0,
  # whose python-sdk pyproject declares a different SDK version, so the new
  # pythonMetadataCheckPhase fails. Skip the check until nixpkgs fixes the
  # version mismatch.
  firecrawl-py' = python3.pkgs.firecrawl-py.overridePythonAttrs {
    dontCheckPythonMetadata = true;
  };

  # pyramid dropped its pkg_resources shim on python 3.14, so slack-bolt's
  # pyramid adapter tests fail at collection with ModuleNotFoundError.
  slack-bolt' = python3.pkgs.slack-bolt.overridePythonAttrs (old: {
    disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
      "tests/adapter_tests/pyramid/"
    ];
  });

  optionalDeps = with python3.pkgs; {
    gateway = [
      # [messaging] / [slack]
      slack-bolt'
      slack-sdk
      python-telegram-bot
      discordpy
      aiohttp
      # [cron]
      croniter
      # [web]
      fastapi
      uvicorn
      # [markdown] — used by matrix and other formatters
      markdown
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      # [matrix] — nixpkgs mautrix lacks the encryption extra, so add its
      # crypto deps explicitly.
      mautrix
      (python-olm.override { olm = clearedOlm; })
      unpaddedbase64
      pycryptodome
      base58
      aiosqlite
      asyncpg
      aiohttp-socks
    ];
    misc = [
      # [cli]
      simple-term-menu
      # [pty]
      ptyprocess
      # [acp]
      agent-client-protocol
      # [voice]
      sounddevice
      numpy
      # [tts-premium]
      elevenlabs
      # [mistral]
      mistralai
      # [bedrock]
      boto3
      # [modal]
      modal
    ];
  };

  # The TUI spawns `$HERMES_PYTHON -m tui_gateway.entry`; sys.executable is the
  # bare interpreter, so give it an env with the runtime deps. The dashboard
  # PTY path copies wrapper env into a nested Node subprocess, which then
  # resolves the gateway import root from HERMES_PYTHON_SRC_ROOT.
  pythonEnv = python3.withPackages (_: hermesDeps);
in
python3.pkgs.buildPythonApplication {
  pname = "hermes-agent";
  inherit version src;
  pyproject = true;

  build-system = with python3.pkgs; [
    setuptools
  ];

  # lazy_deps._is_satisfied enforces exact PyPI pins and tries to pip install
  # into the read-only store on any drift, silently disabling the feature
  # (e.g. nixpkgs aiosqlite 0.21.0 vs hermes pin 0.22.1 disabled matrix).
  # The closure already provides every dep, so presence is sufficient.
  # Dashboard slash workers re-exec the bare sys.executable, which cannot
  # import Hermes modules or its dependencies under Nix; run them with the
  # wrapper-provided interpreter and source root instead of leaking a global
  # PYTHONPATH into every subprocess Hermes spawns.
  patches = [ ./slash-worker-hermes-python.patch ];

  postPatch = ''
    substituteInPlace tools/lazy_deps.py \
      --replace-fail 'Version(installed) in SpecifierSet(spec_tail)' 'True'
  '';

  # setup.py refuses to build wheels/sdists unless it knows this is a Nix
  # (uv2nix-style) build; upstream gates it behind this env var.
  env.HERMES_NIX_BUILD = "1";

  # Upstream pins setuptools<83 in build-system.requires, which nixpkgs'
  # setuptools 83 no longer satisfies; the pin is only about metadata quirks.
  pypaBuildFlags = [ "--skip-dependency-check" ];

  dependencies = hermesDeps;
  optional-dependencies = optionalDeps;

  makeWrapperArgs = [
    "--set"
    "HERMES_TUI_DIR"
    "${hermes-frontend}/lib/hermes-tui"
    "--set"
    "HERMES_WEB_DIST"
    "${hermes-frontend}/share/hermes-web"
    "--set"
    "HERMES_PYTHON"
    "${pythonEnv}/bin/python3"
    "--set"
    "HERMES_PYTHON_SRC_ROOT"
    "${placeholder "out"}/${python3.sitePackages}"
    "--set"
    "HERMES_NODE"
    "${nodejs}/bin/node"
    # Skills are copied to $out/share/hermes in postInstall; point hermes at them.
    "--set"
    "HERMES_BUNDLED_SKILLS"
    "${placeholder "out"}/share/hermes/skills"
    "--set"
    "HERMES_OPTIONAL_SKILLS"
    "${placeholder "out"}/share/hermes/optional-skills"
    # Disable runtime pip installs; absent extras disable cleanly.
    "--set"
    "HERMES_DISABLE_LAZY_INSTALLS"
    "1"
    # node+npm on PATH short-circuits _ensure_tui_node()'s download bootstrap.
    "--prefix"
    "PATH"
    ":"
    "${nodejs}/bin"
  ];

  # Skills are shipped as setup.py data_files, which the wheel build drops;
  # install them manually.
  postInstall = ''
    mkdir -p $out/share/hermes
    cp -r ${src}/skills $out/share/hermes/skills
    cp -r ${src}/optional-skills $out/share/hermes/optional-skills

    # Upstream pyproject.toml (>= 2026.7.30) lost the plugins package-data
    # rule, so wheels ship no plugin.yaml and plugin discovery registers
    # nothing; restore the manifests from the source tree.
    (cd ${src} && find plugins -type f \( -name 'plugin.yaml' -o -name 'plugin.yml' \) \
      -exec install -Dm644 '{}' "$out/${python3.sitePackages}/{}" \;)
  '';

  pythonRelaxDeps = [
    "openai"
    "python-dotenv"
    "tenacity"
    "ruamel.yaml"
    "requests"
    "pydantic"
    "pathspec"
    "firecrawl-py"
    "pyjwt"
    "cryptography"
    "certifi"
    "packaging"
    "urllib3"
    "websockets"
    # nixpkgs moved past upstream's == pins
    "rich"
    "pillow"
    "croniter"
  ];

  pythonImportsCheck = [
    "hermes_cli"
    "hermes_cli.dashboard_auth"
    "hermes_cli.proxy"
    # #4175: adapters swallow ImportError, so assert these import.
    "slack_bolt"
    "discord"
    "telegram.ext"
    "croniter"
    # relay_runtime imports this lazily and silently degrades to a noop
    # runtime when missing, so assert it imports.
    "nemo_relay"
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "--version" ];

  # #4364: wrapper must wire up the TUI and a deps-capable gateway python.
  postInstallCheck = ''
    grep -q HERMES_TUI_DIR $out/bin/hermes
    grep -q HERMES_WEB_DIST $out/bin/hermes
    grep -q HERMES_PYTHON $out/bin/hermes
    grep -q HERMES_PYTHON_SRC_ROOT $out/bin/hermes
    grep -q HERMES_BUNDLED_SKILLS $out/bin/hermes
    grep -q HERMES_OPTIONAL_SKILLS $out/bin/hermes
    test -f ${hermes-frontend}/lib/hermes-tui/dist/entry.js
    test -f ${hermes-frontend}/share/hermes-web/index.html
    test -d $out/share/hermes/skills
    test -d $out/share/hermes/optional-skills
    ${pythonEnv}/bin/python3 -c 'import dotenv, tenacity, openai'
    # Slash workers run HERMES_PYTHON with PYTHONPATH=HERMES_PYTHON_SRC_ROOT.
    PYTHONPATH="$out/${python3.sitePackages}" \
      ${pythonEnv}/bin/python3 -c 'import tui_gateway.slash_worker, yaml'
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    # Matrix E2EE: mautrix.crypto must import and the disable switch wired in.
    ${pythonEnv}/bin/python3 -c 'import mautrix.crypto, asyncpg, aiosqlite'
    grep -q HERMES_DISABLE_LAZY_INSTALLS $out/bin/hermes
  '';

  passthru = {
    category = "AI Assistants";
    inherit hermes-frontend;
  };

  meta = with lib; {
    description = "Self-improving AI agent by Nous Research — creates skills from experience and runs anywhere";
    homepage = "https://hermes-agent.nousresearch.com/";
    changelog = "https://github.com/NousResearch/hermes-agent/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    mainProgram = "hermes";
  };
}
