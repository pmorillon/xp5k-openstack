# Module:: scenario
# Manifest:: openstack/nova.pp
#


class scenario::openstack::compute (
  String $admin_password = $scenario::openstack::params::admin_password,
  String $controller_public_address = $scenario::openstack::params::controller_public_address,
  String $storage_public_address = $scenario::openstack::params::storage_public_address,
  String $data_network = $scenario::openstack::params::private_network
) inherits scenario::openstack::params {

  
  # common config between controller and computes
  class { '::scenario::common::nova': 
    controller_public_address => $controller_public_address,
    storage_public_address    => $storage_public_address
  }

  class {
    '::nova::compute':
      #vnc_keymap  => 'fr',
      vnc_enabled => true;
  }

  class { '::nova::compute::libvirt':
    libvirt_virt_type => 'kvm',
    migration_support => true,
    vncserver_listen  => '0.0.0.0',
  }

  class {'::scenario::common::neutron':
    controller_public_address => $controller_public_address
  }

  class { '::neutron::agents::ml2::ovs':
    enable_tunneling => true,
    local_ip         => ip_for_network($data_network),
    enabled          => true,
    tunnel_types     => ['vxlan'],
  }
}
