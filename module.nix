{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.services.zulip;
in
{
  options.services.zulip = {
    enable = lib.mkEnableOption "zulip";
    package = lib.mkPackageOption pkgs "zulip-server" { };

    enableMemcached = lib.mkEnableOption "";
    enableRedis = lib.mkEnableOption "";

    createPostgresqlDatabase = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether to create a PosgreSQL database for Zulip.
      '';
    };
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra lines to be appended to the the settings.py file.";
    };
    settings = lib.mkOption {
      description = ''
        Zulip server settings. Read more [here](https://zulip.readthedocs.io/en/latest/subsystems/settings.html).
      '';
      type = lib.types.submodule {
        freeformType =
          with lib.types;
          attrsOf (oneOf [
            bool
            int
            str
          ]);
        options = {
          EXTERNAL_HOST = lib.mkOption {
            type = lib.types.str;
          };
          ZULIP_ADMINISTRATOR = lib.mkOption {
            type = lib.types.str;
          };
          ZULIP_SERVICE_PUSH_NOTIFICATIONS = lib.mkOption {
            type = lib.types.bool;
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = lib.mkIf cfg.createPostgresqlDatabase {
      enable = true;
      ensureDatabases = [ "zulip" ];
      ensureUsers = [
        {
          name = "zulip";
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }
      ];
    };

    systemd.services.zulip = {
      description = "Zulip server and web application";
      after = [ "network.target" ] ++ lib.optional cfg.createPostgresqlDatabase "postgresql.service";
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        # Generate secrets if not exists. Note that the file might be a bindmount from the options.
        if [ ! -f /etc/zulip/zulip-secrets.conf ]; then
          install -m600 -o zulip -g zulip /dev/null /etc/zulip/zulip-secrets.conf
          {
            echo "[secrets]"
            echo "avatar_salt = '$(head /dev/urandom | tr -dc 0-9A-F | head -c 32)'"
            echo "rabbitmq_password = '$(head /dev/urandom | tr -dc 0-9A-F | head -c 32)'"
            echo "shared_secret = '$(head /dev/urandom | tr -dc 0-9A-F | head -c 32)'"
            echo "postgres_password = '$(head /dev/urandom | tr -dc 0-9A-F | head -c 32)'"
            echo "secret_key = '$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 50)'"
            echo "camo_key = '$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64)'"
            echo "memcached_password = '$(head /dev/urandom | tr -dc 0-9A-F | head -c 32)'"
            echo "redis_password = '$(head /dev/urandom | tr -dc 0-9A-F | head -c 32)'"
            echo "zulip_org_key = '$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64)'"
            echo "zulip_org_id = '$(cat /proc/sys/kernel/random/uuid)'"
          } > /etc/zulip/zulip-secrets.conf
        fi

        # Not for production
        /run/zulip/zulip-server/scripts/setup/generate-self-signed-cert \
          --exists-ok "''${EXTERNAL_HOST:-$(hostname)}"

        # TODO do this conditionally, if secrets do not yet exist
        /run/zulip/zulip-server/scripts/setup/generate_secrets.py --production

        # TODO do this conditionally if the cache does not yet exist
        /run/zulip/zulip-server/tools/update-prod-static

        # TODO should this only run if e.g. ./env does not exist? or maybe we can make a file called .initialised or something
        PYTHONUNBUFFERED=1 /run/zulip/zulip-server/manage.py register_server
        /run/zulip/zulip-server/manage.py generate_realm_creation_link
      '';

      script = ''
        echo hello
      '';

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 3;
        DynamicUser = true;
        WorkingDirectory = "/var/lib/zulip";

        StateDirectory = [ "zulip" ];
        RuntimeDirectory = [ "zulip" ];
        ConfigurationDirectory = [ "zulip" ];

        BindReadOnlyPaths = let
          toPythonString = v:
            with builtins;
            if isBool v then
              if v then "True" else "False"
            else if isString v then
              "'${replaceStrings [ "'" ]  [ "\\'" ] v}'"
            else
              toString v;
          prod-settings = pkgs.writeTextDir "__init__.py" (
            lib.pipe cfg.settings [
              (lib.mapAttrsToList (key: val: "${key} = ${toPythonString val}"))
              (lib.concatStringsSep "\n")
              (str: ''
                import zproject.prod_settings_template
                ${str}
                ${cfg.extraConfig or ""}
              '')
            ]
          );
        in [
          # TODO: create proper freeform settings
          (let
            zulip-conf = pkgs.writeText "zulip.conf" ''
            [machine]
            deploy_type = production
          '';
          in "${zulip-conf}:/etc/zulip/zulip.conf")
          "${cfg.package}:/var/run/zulip/zulip-server"
          "${prod-settings}:/var/run/zulip/zulip-server/zproject/prod_settings"
        ];
      };
    };
  };
}
