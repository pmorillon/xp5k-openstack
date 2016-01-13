# Module:: scenario
# Manifest:: common/neutron.pp
#

class scenario::common::neutron (
  String $controller_public_address = $scenario::openstack::params::controller_public_address,
) {

  # common config
  class { '::neutron':
    rabbit_user           => 'neutron',
    rabbit_password       => 'an_even_bigger_secret',
    rabbit_host           =>  $controller_public_address,
    allow_overlapping_ips => true,
    core_plugin           => 'ml2',
    service_plugins       => ['router', 'metering'],
    debug                 => true,
    verbose               => true,
  }

  class { '::neutron::plugins::ml2':
    type_drivers         => ['vxlan', 'flat', 'vlan'],
    tenant_network_types => ['vxlan', 'flat', 'vlan'],
    mechanism_drivers    => ['openvswitch'],
  }


}

