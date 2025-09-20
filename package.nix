{ lib
, runCommand
, callPackage
, fetchFromGitHub
, python3
, writeShellApplication
, fetchPypi
, pnpm
, stdenv
, nodejs
, libffi
, # libffi-devel
  openldap
, # openldap-devel
  libxml2
, #libxml2-dev
  libxslt
, #libxslt1-dev
  libpq
, # libpq-dev
  openssl
, # libssl-dev
  file
, # libmagic1
  libyaml
, #libyaml-dev
  xmlsec
, # libxmlsec1-dev
  pkg-config
, cyrus_sasl
, # libsasl2-dev
  vips
, # libvips # libvips-tools
  git
, curl
, jq
, crudini
, util-linux
, runtimeShell
, libxcrypt
}:

# phases:
# fetch -> unpack -> patch -> configure -> build -> check -> install -> fixup

let

  python = python3.override {
    packageOverrides = final: prev: {
      django = prev.django_5;
    };
  };

  python-pkgs = python.pkgs;

  jsx-lexer = python-pkgs.buildPythonPackage rec {
    propagatedBuildInputs = with python-pkgs; [
      pygments # >= 2.12.0
    ];
    pname = "jsx-lexer";
    version = "2.0.1";
    pyproject = true;
    build-system = with python-pkgs; [ setuptools ];
    src = fetchPypi {
      inherit pname version;
      hash = "sha256-DZqmU+dNeXPXQCHd6DSYlsDfCU2OQDSbkrNeCTDtf3E=";
    };
  };

  django-bitfield = python-pkgs.buildPythonPackage rec {
    propagatedBuildInputs = with python-pkgs; [
      django # >=1.11.29
      six # not in master anymore
    ];
    pname = "django-bitfield";
    version = "2.2.0";
    pyproject = true;
    build-system = with python-pkgs; [ setuptools ];
    src = fetchPypi {
      inherit pname version;
      hash = "sha256-GyEmKsxOwK8/gu0ESYoFbNnVRSUyrAJ3HgBINaNOCxs=";
    };
  };

  uhashring = python-pkgs.buildPythonPackage rec {
    propagatedBuildInputs = with python-pkgs; [ ];
    pname = "uhashring";
    version = "2.4";
    pyproject = true;
    build-system = with python-pkgs; [ hatchling ];
    src = fetchPypi {
      inherit pname version;
      hash = "sha256-irMIaPSsB50qjFjEPDWilDOe/vewadJgQoYX2kjl8CA=";
    };
  };

  python-binary-memcached = python-pkgs.buildPythonPackage rec {
    propagatedBuildInputs = with python-pkgs; [
      six
      uhashring # python >= 3.6
    ];
    pname = "python_binary_memcached"; # Tarball was uploaded with an underscore
    version = "0.31.4";
    pyproject = true;
    build-system = with python-pkgs; [ setuptools ];
    src = fetchPypi {
      inherit pname version;
      hash = "sha256-8YO8Z/0hjAHrwL9OmSmiEN1aoH/aU9W2J9C0Q7duKBg=";
    };
  };

  # Repo archived on jun 16 2022
  django-bmemcached = python-pkgs.buildPythonPackage rec {
    propagatedBuildInputs = with python-pkgs; [
      python-binary-memcached
    ];
    pname = "django-bmemcached";
    version = "0.3.0";
    pyproject = true;
    build-system = with python-pkgs; [ setuptools ];
    src = fetchPypi {
      inherit pname version;
      hash = "sha256-Tkt9lyFtuuMxwd4Q5pnKIoBLlOw6kNJ2LdXRRuaYaoo=";
    };
  };

  # python 2 package ???
  pyoembed = python-pkgs.buildPythonPackage rec {
    propagatedBuildInputs = with python-pkgs; [
      requests
      beautifulsoup4
      lxml
    ];
    pname = "pyoembed";
    version = "0.1.2";
    pyproject = true;
    build-system = with python-pkgs; [ setuptools ];
    src = fetchPypi {
      inherit pname version;
      hash = "sha256-D3VcgwgDnx5JI46V6pTvFqoIrdnzIHW6E6ubZfMv9YI=";
    };
  };

  zulip-bots = python-pkgs.buildPythonPackage rec {
    propagatedBuildInputs = with python-pkgs; [
      pip
      zulip
      html2text
      lxml
      beautifulsoup4
      typing-extensions # >=4.5.0
      importlib-metadata # >=3.6
    ];
    pname = "zulip_bots"; # Tarball was uploaded with an underscore
    version = "0.9.0";
    pyproject = true;
    build-system = with python-pkgs; [ setuptools ];
    src = fetchPypi {
      inherit pname version;
      hash = "sha256-lJJaS9fDVYvw4Mw+gwIdai8hOYJHRQgauqYFo9AS43o=";
    };
  };

  uwsgi = python-pkgs.buildPythonPackage rec {
    propagatedBuildInputs = with python-pkgs; [ ];
    pname = "uwsgi";
    version = "2.0.30";
    pyproject = true;
    build-system = with python-pkgs; [ setuptools ];
    src = fetchPypi {
      inherit pname version;
      hash = "sha256-wSqmUhJPBirCFgd9pZ9tJHvX75OCNERYgVUuWK+x618=";
    };
    buildInputs = [ libxcrypt ];
  };

  xsentinels = python-pkgs.buildPythonPackage rec {
    propagatedBuildInputs = with python-pkgs; [
      typing-inspect
    ];
    pname = "xsentinels"; # Tarball was uploaded with an underscore
    version = "1.3.1";
    pyproject = true;
    build-system = with python-pkgs; [ poetry-core ];
    src = fetchPypi {
      inherit pname version;
      hash = "sha256-ZehXZDoCNyljRsRopnYtJCsvOpcMyTqgMlEnq6iaeJo=";
    };
  };

  pydantic-partials = python-pkgs.buildPythonPackage rec {
    propagatedBuildInputs = with python-pkgs; [
      pydantic
      xsentinels
    ];
    pname = "pydantic_partials"; # Tarball was uploaded with an underscore
    version = "2.0.2";
    pyproject = true;
    build-system = with python-pkgs; [ poetry-core ];
    src = fetchPypi {
      inherit pname version;
      hash = "sha256-eu7ZDDBaIsS6dNnhjqDujms6C61+jGqbNegSS4i9VKs=";
    };
  };

  python-env = python.buildEnv.override {
    extraLibs = with python.pkgs; [
      django #django==5.2.*
      asgiref
      typing-extensions
      jinja2
      markdown
      pygments
      jsx-lexer # not in nixpkgs
      uri-template
      regex
      ipython
      pyvips
      sqlalchemy #sqlalchemy==1.4.*
      greenlet
      boto3
      mypy-boto3-s3
      mypy-boto3-ses
      mypy-boto3-sns
      mypy-boto3-sqs
      defusedxml
      python-ldap
      django-auth-ldap
      django-bitfield # not in nixpkgs
      firebase-admin
      html2text
      #talon-core # not in nixpkgs # not in pypi either ???
      css-inline
      pyjwt
      pika
      psycopg2
      python-binary-memcached # not in nixpkgs
      django-bmemcached # not in nixpkgs
      python-dateutil
      redis
      tornado
      orjson
      aioapns
      polib
      virtualenv-clone
      beautifulsoup4
      pyoembed # not in nixpkgs
      python-magic
      zulip
      zulip-bots # not in nixpkgs
      dnspython
      social-auth-app-django
      social-auth-core
      python3-saml
      cryptography
      lxml
      django-two-factor-auth
      stripe
      disposable-email-domains
      jsonref
      pyahocorasick
      decorator
      zxcvbn
      requests
      requests-oauthlib
      openapi-core
      werkzeug #werkzeug<3.1.2 # https://github.com/python-openapi/openapi-core/issues/938
      sentry-sdk
      tlds
      pyuca
      backoff
      pymongo
      google-re2
      django-cte
      django-scim2
      circuitbreaker
      django-stubs-ext
      pydantic
      annotated-types
      litellm
      uwsgi # not in nixpkgs
      prometheus-client
      altcha
      aiosmtpd #aiosmtpd>=1.4.6
      pydantic-partials # not in nixpkgs
      pynacl
      chardet #chardet>=5.1.0

      pyyaml
    ]
    ++ django.optional-dependencies.argon2
    ++ social-auth-core.optional-dependencies.azuread
    ++ social-auth-core.optional-dependencies.saml
    ++ django-two-factor-auth.optional-dependencies.call
    #++ django-two-factor-auth.optional-dependencies.phonenumberslite # not in nixpkgs
    ++ django-two-factor-auth.optional-dependencies.sms
    ++ requests.optional-dependencies.security
    ;
    ignoreCollisions = false;
  };

  src = fetchFromGitHub {
    owner = "zulip";
    repo = "zulip";
    tag = "10.4";
    hash = "sha256-sIfcxEnF8RUluPDljtNY6sU9OFZgCgG431xb8GSZRno=";
  };

  zulip-server = stdenv.mkDerivation (finalAttrs: {
    pname = "zulip-server";
    version = "10.4";

    src = src;

    pnpmDeps = pnpm.fetchDeps {
      inherit (finalAttrs) pname version src;
      fetcherVersion = 1;
      hash = "sha256-UAMq7wmttfr6vnLJGvaHJ3QXbwYMctTal9r3IMxPXaA=";
    };

    buildInputs = [
      nodejs
      pnpm.configHook
      python-env

      git
      curl
      jq
      crudini

      #build-essential
      libffi # libffi-devel
      openldap # openldap-devel
      #python3-devel
      #python3-pip
      #virtualenv
      libxml2 # libxml2-dev
      libxslt # libxslt1-dev
      libpq # libpq-dev
      openssl # libssl-dev
      file # libmagic1
      libyaml # libyaml-dev
      xmlsec # libxmlsec1-dev
      pkg-config
      cyrus_sasl # libsasl2-dev
      vips # libvips # libvips-tools
    ];

    postPatch = ''
      echo "def setup_path(): pass" > scripts/lib/setup_path.py

      substituteInPlace scripts/setup/generate-self-signed-cert \
        --replace-fail 'getopt' '${lib.getExe' util-linux "getopt"}' \
        --replace-fail "apt-get install -y openssl" ":" \
        --replace-fail 'openssl' '${lib.getExe openssl}' \
        --replace-fail "if [ \"\$EUID\" -ne 0 ]; then" "if false; then"

      substituteInPlace zproject/configured_settings.py \
        --replace-fail "from .prod_settings import *" "import sys; sys.path.append(\"/var/lib/zulip\"); from prod_settings import *"

      substituteInPlace zproject/computed_settings.py \
        --replace-fail /srv /run/zulip \
        --replace-fail 'zulip_path("/var/log/zulip' '(f"{os.environ.get("ZULIP_LOG_DIR", "/var/log/zulip")}' \
        --replace-fail 'zulip_path("/home/zulip' '(f"{os.environ.get("ZULIP_STATE_DIR", "/var/lib/zulip")}'

      substituteInPlace scripts/lib/zulip_tools.py \
        --replace "args = [\"sudo\", *sudo_args, \"--\", *args]" "pass" \
        --replace "/home" "$out/env/home"

      substituteInPlace zerver/lib/compatibility.py \
        --replace "LAST_SERVER_UPGRADE_TIME = datetime.strptime" "LAST_SERVER_UPGRADE_TIME = timezone_now() or datetime.strptime"


      # === Patches for update-prod-static ===

      substituteInPlace tools/update-prod-static \
        --replace "sanity_check.check_venv(__file__)" "" \
        --replace "setup_node_modules(production=True)" "" \
        --replace 'run(["./tools/webpack", "--quiet"])' \
                  "run([os.environ['ZULIP_TOOLS_WEBPACK_REPLACEMENT_SCRIPT'], os.environ['ZULIP_WEB']])"

      substituteInPlace tools/setup/emoji/build_emoji \
        --replace 'EMOJI_CACHE_BASE_PATH = "/srv/zulip-emoji-cache"' \
                  "EMOJI_CACHE_BASE_PATH = os.path.join(os.environ['TMP'], 'emoji-cache')" \
        --replace 'TARGET_STATIC_EMOJI = os.path.join(ZULIP_PATH, "static", "generated", "emoji")' \
                  "TARGET_STATIC_EMOJI = os.path.join(os.environ['ZULIP_STATIC_GENERATED'], 'emoji')" \
        --replace 'target_dir = os.path.join(ZULIP_PATH, "web", "generated", subdir)' \
                  "target_dir = os.path.join(os.environ['ZULIP_WEB_GENERATED'], subdir)" \
        --replace 'shutil.copyfile(input_img_file, output_img_file)' ""

      # substituteInPlace tools/setup/generate_bots_integrations_static_files.py \
      substituteInPlace tools/setup/generate_zulip_bots_static_files.py \
        --replace '"static/generated' "f\"{os.environ['ZULIP_STATIC_GENERATED']}"

      substituteInPlace tools/setup/build_pygments_data \
        --replace 'OUT_PATH = os.path.join(ZULIP_PATH, "web", "generated", "pygments_data.json")' \
                  'OUT_PATH = os.path.join(os.environ["ZULIP_WEB_GENERATED"], "pygments_data.json")'

      substituteInPlace tools/setup/build_timezone_values \
        --replace 'OUT_PATH = os.path.join(ZULIP_PATH, "web", "generated", "timezones.json")' \
                  'OUT_PATH = os.path.join(os.environ["ZULIP_WEB_GENERATED"], "timezones.json")'

      substituteInPlace tools/setup/generate_landing_page_images.py \
        --replace 'GENERATED_IMAGES_DIR = os.path.join(LANDING_IMAGES_DIR, "generated")' \
                  'GENERATED_IMAGES_DIR = os.environ["ZULIP_GENERATED_IMAGES_DIR"]'
    '';

    installPhase = ''
      runHook preInstall

      mkdir "$out"

      cp -r . "$out"/zulip
      chmod -R +w "$out"/zulip
      cp -r node_modules "$out"/zulip

      mkdir -p $out/env/etc/ssl/private
      mkdir -p $out/env/etc/ssl/certs
      mkdir -p $out/env/etc/zulip

      mkdir -p "$out"/zulip/zproject/prod_settings

      #mkdir -p prod-static/serve
      #cp -rT prod-static/serve $out/env/home/zulip/prod-static

      mkdir -p "$out"/bin
      pushd "$out"/bin
      ln -s ../zulip/manage.py zulip-manage
      ln -s ../zulip/tools/update-prod-static zulip-update-prod-static
      ln -s ../zulip/scripts/setup/generate-self-signed-cert zulip-generate-self-signed-cert
      ln -s ../zulip/scripts/setup/generate_secrets.py zulip-generate-secrets
      popd

      runHook postInstall
    '';

    postFixup = ''
      patchShebangs --build "$out/zulip"

      patchShebangs --host "$out/zulip"

      substituteInPlace zproject/computed_settings.py \
        --replace "$out/env" "./env"
    '';

    passthru.static-content = zulip-static-content;
  });

  # TODO: would it be easier if this was just included in the zulip-server derivation?
  #       How much data is it, would it be unfair to put it in the binary cache?
  zulip-static-content = callPackage (
    {
      runCommandLocal,
      zulip-server,
      vips,
      writeShellScript,
      webpack-cli,

      # TODO: remove
      strace,
    }:
    runCommandLocal "zulip-static-content"
      {
        nativeBuildInputs = [ vips ];

        env = {
          DISABLE_MANDATORY_SECRET_CHECK = "True";

          ZULIP_WEB = "${placeholder "out"}/web";
          ZULIP_WEB_GENERATED = "${placeholder "out"}/web/generated";
          ZULIP_STATIC_GENERATED = "${placeholder "out"}/static/generated";
          ZULIP_GENERATED_IMAGES_DIR = "${placeholder "out"}/static/images/landing-page/hello/generated";

          ZULIP_LOG_DIR = "/tmp";
          ZULIP_STATE_DIR = "/tmp";

          ZULIP_TOOLS_WEBPACK_REPLACEMENT_SCRIPT = writeShellScript "zulip-tools-webpack-replacement-script" ''
            export BABEL_DISABLE_CACHE=1
            export BROWSERSLIST_IGNORE_OLD_DATA=1

            cd "$1"

            ${lib.getExe webpack-cli} build ${lib.cli.toGNUCommandLineShell { } {
              disable-interpret = true;
              mode = "production";
              env = "ZULIP_VERSION=${zulip-server.version}";
              stats = "errors-only";
            }}
          '';
        };
      }
      ''
        # TODO: does `web,static,node_modules` need to be stored in `$out` or can we create a webpack
        #       bundle in a tmpdir and then move it to `$out`?
        mkdir -p "$out"
        cp -r '${zulip-server}'/zulip/{web,static,node_modules} "$out/"
        chmod -R +w "$out/"

        # ${lib.getExe strace} -f -e trace=file '${zulip-server}'/zulip/tools/update-prod-static
        '${zulip-server}'/zulip/tools/update-prod-static
      ''
  ) { inherit zulip-server; };
in
zulip-server
