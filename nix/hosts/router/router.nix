{
  config,
  pkgs,
  lib,
  ...
}:
{
  # false -> NIC: eth0 *
  # true -> NIC: enp0s6/ens6
  networking.usePredictableInterfaceNames = false;

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

  networking = {
    useDHCP = false;
    vlans = {
      wan = {
        id = 10;
        # interface = "enp0s6";
        # interface = "enp0s7";
        interface = "enp0s4f0";
      };
      lan = {
        id = 20;
        # interface = "enp0s6";
        # interface = "enp0s7";
        interface = "enp0s4f0";
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
      # enp0s2 = {
      #   ipv4.addresses = [
      #     {
      #       address = "10.1.1.30";
      #       prefixLength = 24;
      #     }
      #   ];
      # };
    };

    # No local firewall.
    nat.enable = false;
    firewall.enable = lib.mkForce false;

    nftables = {
      enable = true;
      ruleset = ''
        table inet filter {
          set monitoring-ports {
            type inet_service;
            elements = { ${builtins.concatStringsSep ", " (builtins.map builtins.toString config.mymodules.services.prometheus.exporters.portsUsed)} };
          }

          set ssh-ports {
            type inet_service;
            elements = { ${builtins.concatStringsSep ", " (builtins.map builtins.toString config.services.openssh.ports)} };
          }

          # enable flow offloading for better throughput
          flowtable f {
            hook ingress priority 0;
            devices = { enp0s4f0 };
          }

          chain input {
            type filter hook input priority 0; policy drop;

            # iifname { "lan" } accept comment "Allow local network to access the router"
            iifname { "lan" } tcp dport @monitoring-ports accept comment "Allow TCP monitoring ports on LAN"
            iifname { "lan" } tcp dport @ssh-ports accept comment "Allow SSH access from LAN"

            iifname "wan" ct state { established, related } accept comment "Allow established traffic"
            iifname "wan" icmp type { echo-request, destination-unreachable, time-exceeded } counter accept comment "Allow select ICMP"
            iifname "wan" counter drop comment "Drop all other unsolicited traffic from wan"

            iifname "lo" accept comment "Accept everything from loopback interface"
          };

          chain forward {
            type filter hook forward priority filter; policy drop;

            # enable flow offloading for better throughput
            ip protocol { tcp, udp } flow offload @f

            # Drop packets with private IP addresses (RFC 1918) going to WAN from any interface
            oifname "wan" ip daddr {
              10.0.0.0/8,
              172.16.0.0/12,
              192.168.0.0/16
            } drop comment "Block private IPv4 ranges from WAN"

            # Drop IPv6 ULA (Unique Local Address) range going to WAN from any interface
            oifname "wan" ip6 daddr fc00::/7 drop comment "Block private IPv6 ranges from WAN"


            iifname { "lan" } oifname { "wan" } accept comment "Allow trusted LAN to WAN"
            iifname { "wan" } oifname { "lan" } ct state { established, related } accept comment "Allow established back to LANs"
          }

          chain postrouting {
            type nat hook postrouting priority 100; policy accept;

            oifname "wan" masquerade
          }
        }
      '';
      preCheckRuleset = "sed 's/.*devices.*/devices = { lo }/g' -i ruleset.conf";
    };
  };

  environment.systemPackages = with pkgs; [
    ethtool # manage NIC settings (offload, NIC feeatures, ...)
    tcpdump # view network traffic
    conntrack-tools # view network connection states
  ];

}
