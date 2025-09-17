{ lib
, runCommand
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
in
stdenv.mkDerivation (finalAttrs: {
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
    getopt

    #build-essential
    libffi # libffi-devel
    openldap # openldap-devel
    #python3-devel
    #python3-pip
    #virtualenv
    libxml2 #libxml2-dev
    libxslt #libxslt1-dev
    libpq # libpq-dev
    openssl # libssl-dev
    file # libmagic1
    libyaml #libyaml-dev
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
      --replace-fail "/var" "$out/env/var" \
      --replace-fail "/home" "$out/env/home"

    substituteInPlace tools/update-prod-static \
      --replace "sanity_check.check_venv(__file__)" "" \
      --replace "setup_node_modules(production=True)" "" \

    substituteInPlace scripts/lib/zulip_tools.py \
      --replace "args = [\"sudo\", *sudo_args, \"--\", *args]" "pass" \
      --replace "/home" "$out/env/home"

    substituteInPlace tools/setup/emoji/build_emoji \
      --replace "/srv" "$out/env/srv"

    substituteInPlace zerver/lib/compatibility.py \
      --replace "LAST_SERVER_UPGRADE_TIME = datetime.strptime" "LAST_SERVER_UPGRADE_TIME = timezone_now() or datetime.strptime"
  '';

  installPhase = ''
    mkdir "$out"

    cp -r . "$out"/zulip
    chmod -R +w "$out"/zulip
    cp -r node_modules "$out"/zulip

    mkdir -p $out/env/etc/ssl/private
    mkdir -p $out/env/etc/ssl/certs
    mkdir -p $out/env/etc/zulip

    #mkdir -p prod-static/serve
    #cp -rT prod-static/serve $out/env/home/zulip/prod-static

    mkdir -p $out/bin

    for script in generate-self-signed-cert generate-secrets update-prod-static manage; do
      cp $out/zulip/scripts/setup/$script $out/bin
    done
  '';

  postFixup = ''
    patchShebangs --build "$out/zulip"

    patchShebangs --host "$out/zulip"

    substituteInPlace zproject/computed_settings.py \
      --replace "$out/env" "./env"
  '';
})
