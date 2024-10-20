_: {
  mymodules = {
    services = {
      tailscale = {
        enable = true;
        sopsAuthKey = "tailscale/auth_key";
      };
    };
  };

  boot.kernel = {
    sysctl = {
      "net.ipv4.conf.all.forwarding" = true;
      # TODO: Check ipv6
      "net.ipv6.conf.all.forwarding" = false;

      # TODO: Validate these options
      # "net.ipv4.conf.all.rp_filter" = 1;
      # "net.ipv4.conf.default.rp_filter" = 1;
      # "net.ipv4.conf.wan.rp_filter" = 1;
    };
  };
}
