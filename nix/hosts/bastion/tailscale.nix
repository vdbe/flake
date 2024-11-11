_: {
  mymodules = {
    services = {
      tailscale = {
        enable = true;
        sopsAuthKey = "tailscale/auth_key";
      };
    };
  };

  services.tailscale = {
    extraUpFlags = [ "--advertise-routes=10.1.1.0/24" ];
    useRoutingFeatures = "server";
  };
}
