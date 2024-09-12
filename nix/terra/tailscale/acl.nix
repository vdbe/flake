{ config, ... }:
let
  inherit (builtins) map attrValues concatLists;
  inherit (config.mymodules.tailscale.tags) tags;

  mkAcl = src: dst: { inherit src dst; };

  mkDestinationPorts = destination: map (port: "${destination}:${builtins.toString port}");
  mkDestinations =
    destinations: ports:
    (concatLists (map (destination: mkDestinationPorts destination ports) destinations));

  defaultPorts = [
    22
    80
    443
  ];

  # informational tags do not provide access
  informationalTags = with tags; [
    desktop
    laptop
    phone
  ];

in
{
  mymodules.tailscale.acl.acls = [
    (mkAcl tags.personal "*:*")
    (mkAcl tags.server "${tags.server}:*")
  ];

  mymodules.tailscale.acl.tests =
    [
      {
        # Check if access is not lost
        src = tags.personal;
        accept = mkDestinations (attrValues tags) defaultPorts;
      }

      {
        src = tags.server;
        accept = mkDestinations [ tags.server ] defaultPorts;
        deny = mkDestinations (with tags; [ personal ]) defaultPorts;
      }
    ]
    ++ (concatLists [
      # Check if no access is provided _from_ `informationalTags`
      (map (src: {
        inherit src;
        deny = mkDestinations (attrValues tags) defaultPorts;

      }) informationalTags)

      # Check if no access is provided _to_ `informationalTags`
      (map (src: {
        inherit src;
        deny = mkDestinations informationalTags defaultPorts;

      }) (with tags; [ server ]))
    ]);

}
