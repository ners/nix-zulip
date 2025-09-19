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
        # TODO: allow generating a zulip-secrets.conf from declarative options instead.
        # Generate secrets if not exists.
        if [ ! -f /etc/zulip/zulip-secrets.conf ]; then
          install -m600 -o zulip -g zulip /dev/null /etc/zulip/zulip-secrets.conf
          ZULIP_SECRETS_CONTENT=(
            "[secrets]"
            "avatar_salt = '$(head /dev/urandom | tr -dc 0-9A-F | head -c 32)'"
            "rabbitmq_password = '$(head /dev/urandom | tr -dc 0-9A-F | head -c 32)'"
            "shared_secret = '$(head /dev/urandom | tr -dc 0-9A-F | head -c 32)'"
            "postgres_password = '$(head /dev/urandom | tr -dc 0-9A-F | head -c 32)'"
            "secret_key = '$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 50)'"
            "camo_key = '$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64)'"
            "memcached_password = '$(head /dev/urandom | tr -dc 0-9A-F | head -c 32)'"
            "redis_password = '$(head /dev/urandom | tr -dc 0-9A-F | head -c 32)'"
            "zulip_org_key = '$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64)'"
            "zulip_org_id = '$(cat /proc/sys/kernel/random/uuid)'"
          )
          printf "%s\n" "''${ZULIP_SECRETS_CONTENT[@]}" > /etc/zulip/zulip-secrets.conf
        fi

        # TODO do this conditionally if the cache does not yet exist
        /run/zulip/zulip-server/tools/update-prod-static

        # TODO should this only run if e.g. ./env does not exist? or maybe we can make a file called .initialised or something 
        PYTHONUNBUFFERED=1 /run/zulip/zulip-server/manage.py register_server
        /run/zulip/zulip-server/manage.py generate_realm_creation_link
      '';

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 3;
        DynamicUser = true;
        WorkingDirectory = "/var/lib/zulip";

        ExecStart = "${pkgs.coreutils}/bin/echo TODO: start the program";

        StateDirectory = [ "zulip" ];
        RuntimeDirectory = [ "zulip/zulip-server" ];
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
          "${cfg.package}/zulip:/run/zulip/zulip-server"
          "${prod-settings}:/run/zulip/zulip-server/zproject/prod_settings"
        ];
      };
    };
  };
}
