_: {
  # false -> NIC: eth0 *
  # true -> NIC: enp0s6/ens6
  networking.usePredictableInterfaceNames = false;

  boot.kernel = {
    sysctl = {
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv6.conf.all.forwarding" = false;
    };
  };

  networking = {
    useDHCP = false;
    vlans = {
      wan = {
        id = 10;
        interface = "enp0s6";
        # interface = "enp0s7";
      };
      lan = {
        id = 20;
        interface = "enp0s6";
        # interface = "enp0s7";
      };
    };

    interfaces = {
      # Handle the VLANs
      wan.useDHCP = true;
      lan = {
        ipv4.addresses = [
          {
            address = "10.1.1.1";
            prefixLength = 24;
          }
        ];
      };
      enp0s2 = {
        ipv4.addresses = [
          {
            address = "10.1.1.30";
            prefixLength = 24;
          }
        ];
      };
    };
  };

}
