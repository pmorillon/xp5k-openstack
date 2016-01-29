# Module:: scenario
# Manifest:: openstack/nova.pp
#


class scenario::openstack::compute (
  String $admin_password = $scenario::openstack::params::admin_password,
  String $controller_public_address = $scenario::openstack::params::controller_public_address,
  String $storage_public_address = $scenario::openstack::params::storage_public_address,
  String $data_network = $scenario::openstack::params::data_network
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

  # Bind to /tmp to get some space
  file {
    '/tmp/nova':
      ensure => directory;
    ['/tmp/nova/images', '/tmp/nova/instances']:
      ensure  => directory,
      owner   => nova,
      group   => nova,
      require => File['/tmp/nova'];
  }

  mount {
    '/var/lib/nova/instances':
      ensure  => mounted,
      device  => '/tmp/nova/instances',
      fstype  => 'none',
      options => 'rw,bind';
    '/var/lib/nova/images':
      ensure  => mounted,
      device  => '/tmp/nova/images',
      fstype  => 'none',
      options => 'rw,bind',
  }

  Package['nova-common'] -> File['/tmp/nova/images'] -> Mount['/var/lib/nova/images']
  Package['nova-common'] -> File['/tmp/nova/instances'] -> Mount['/var/lib/nova/instances']

}
