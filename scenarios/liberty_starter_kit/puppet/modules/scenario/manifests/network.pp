# Module:: scenario
# Manifest:: network.pp
#

class scenario::network (
  String $primary_interface = 'eth0',
  String $external_bridge = 'br-ex'
){

  augeas {
    $primary_interface:
      context => '/files/etc/network/interfaces',
      changes => [
        "set iface[. = '${primary_interface}'] ${primary_interface}",
        "set iface[. = '${primary_interface}']/ovs_bridge br-ex",
        "set iface[. = '${primary_interface}']/ovs_type OVSPort"
        ];
      $external_bridge:
        context => '/files/etc/network/interfaces',
        changes => [
          "set iface[. = '${external_bridge}'] ${external_bridge}",
          "set iface[. = '${external_bridge}']/family inet",
          "set iface[. = '${external_bridge}']/method manual",
          "set iface[. = '${external_bridge}']/ovs_type OVSBridge",
          "set iface[. = '${external_bridge}']/ovs_ports ${primary_interface}",
          ];
  }

  exec {
    "/sbin/ifup ${primary_interface}":
      refreshonly => true;
    "/sbin/ifup ${external_bridge}":
      refreshonly => true;
  }

  service {
    'networking':
  }

  Augeas[$primary_interface] -> Augeas[$external_bridge]
  Augeas[$primary_interface] ~> Service['networking']
  Augeas[$external_bridge] ~> Service['networking']

}
