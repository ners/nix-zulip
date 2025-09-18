{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.services.zulip;
  toPythonString = v:
    with builtins;
    if isBool v then
      if v then "True" else "False"
    else if isString v then
      "'${replaceStrings [ "'" ]  [ "\\'" ] v}'"
    else
      toString v;
  prod-settings = pkgs.writeText "prod_settings.py" (
    lib.pipe cfg.settings [
      (lib.mapAttrsToList (key: val: "${key} = ${toPythonString val}"))
      (lib.concatStringsSep "\n")
      (str: ''
        import ${cfg.package}/zulip/zproject/prod_settings_template.py
        ${str}
        ${cfg.extraConfig or ""}
        ${if cfg.extraConfigFile == null then "" else "import ${cfg.extraConfigFile}"}
      '')
    ]
  );
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
    extraConfigFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Python file to be imported in the settings.py file.";
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

      script = ''
        cp -r "${cfg.package}/env" .
        chmod -R +w .
        mkdir -p etc/zulip

        cat > env/etc/zulip/zulip.conf << EOF
        [machine]
        deploy_type = production
        EOF

        #ln -s ${prod-settings} $out/zproject/prod-settings.py
    
        # Not for production
        ${cfg.package}/zulip/scripts/setup/generate-self-signed-cert \
          --exists-ok "''${EXTERNAL_HOST:-$(hostname)}"

        # TODO do this conditionally, if secrets do not yet exist
        ${cfg.package}/zulip/scripts/setup/generate_secrets.py --production

        # TODO do this conditionally if the cache does not yet exist
        python ${cfg.package}/zulip/tools/update-prod-static

        # TODO should this only run if e.g. ./env does not exist? or maybe we can make a file called .initialised or something 
        PYTHONUNBUFFERED=1 "${cfg.package}/zulip/manage.py" register_server
        "${cfg.package}/zulip/manage.py" generate_realm_creation_link
      '';

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 3;
        DynamicUser = true;
        WorkingDirectory = "/var/lib/zulip";
        # TODO do we need these?
        StateDirectory = "zulip";
        RuntimeDirectory = "zulip";
      };
    };
  };
}
