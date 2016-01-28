# Module:: scenario
# Manifest:: openstack/network.pp
#

class scenario::openstack::network (
  String $admin_password = $scenario::openstack::params::admin_password,
  String $controller_public_address = $scenario::openstack::params::controller_public_address,
  String $data_network = $scenario::openstack::params::data_network
) inherits scenario::openstack::params {


  class {'::scenario::common::neutron':
    controller_public_address => $controller_public_address
  }

  class { '::neutron::agents::ml2::ovs':
    enable_tunneling => true,
    local_ip         => ip_for_network($data_network),
    tunnel_types     => ['vxlan'],
    bridge_mappings  => ["public:br-ex"],
  }

  class { '::neutron::agents::l3':
    debug => true,
  }
  
  class { '::neutron::agents::dhcp':
    dnsmasq_config_file => '/etc/dnsmasq.conf',
    debug               => true,
  }

  class { '::neutron::agents::metering':
    debug => true,
  }

  class { '::neutron::agents::metadata':
    debug         => true,
    auth_password => $admin_password,
    shared_secret => $admin_password,
    auth_url      => "http://${controller_public_address}:35357/v2.0",
    metadata_ip   => $controller_public_address

  }

  file { '/etc/dnsmasq.conf':
    ensure => present,
    source => "puppet:///modules/scenario/dnsmasq.conf",
    notify => Service["neutron-dhcp-agent"]
  }

}
