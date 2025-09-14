{
  name = "zulip";

  nodes = {
    server =
      {
        imports = [ ./module.nix ];
        services.zulip = {
          enable = true;
          settings = {
            EXTERNAL_HOST = "example.com";
            ZULIP_ADMINISTRATOR = "admin@example.com";
            ZULIP_SERVICE_PUSH_NOTIFICATIONS = true;
          };
        };
      };
  };

  testScript = ''
    start_all()
    vm.wait_for_unit("multi-user.target")
  '';
}
