{ pkgs, ... }:

{
  networking.firewall.enable = false;

  environment.systemPackages = [ pkgs.curl ];

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "::";
        http_port = 80;
      };

      analytics = {
        check_for_updates = false;
        check_for_plugin_updates = false;
        feedback_links_enabled = false;
        reporting_enabled = false;
      };

      # we will only be using grafana as ephemeral service
      # so disable https setup and only create admin user
      users.allow_org_create = false;
      users.allow_sign_up = false;
      # set a very low number here so we can get high resolution data
      dashboards.min_refresh_interval = "0.01ms";
      security = {
        disable_gravatar = true;
        cookie_secure = false;
        disable_initial_admin_creation = false;
        admin_user = "admin";
        admin_password = "admin";
        admin_email = "admin@localhost";
      };
    };

    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "prometheus";
          type = "prometheus";
          url = "http://exporter/prometheus";
          editable = true;
        }
        {
          name = "loki";
          type = "loki";
          url = "http://exporter/loki";
          editable = true;
        }
      ];
    };
  };
}
