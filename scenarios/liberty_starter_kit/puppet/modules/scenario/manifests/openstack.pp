# Module:: scenario
# Manifest:: openstack.pp
#

class scenario::openstack (
  String $package_provider = $scenario::openstack::params::package_provider,
  String $admin_password = $scenario::openstack::params::admin_password,
  String $primary_interface = $scenario::openstack::params::primary_interface
) inherits scenario::openstack::params {


  class { 'scenario::openstack::mysql': }
  class { 'scenario::openstack::rabbitmq': }

  class {
    'scenario::openstack::keystone':
      admin_password => $admin_password;
  }

  class {
    'scenario::openstack::neutron':
      admin_password => $admin_password;
  }

  class {
    'scenario::openstack::glance':
      admin_password => $admin_password;
  }

  class {
    'scenario::openstack::nova':
      admin_password => $admin_password;
  }

  # Configure resources
  #
  $os_auth_options = "--os-username admin --os-password ${admin_password} --os-tenant-name openstack --os-auth-url http://127.0.0.1:5000/v2.0"

  exec {
    'get cyros image':
      command => '/usr/bin/wget -O /tmp/cirros.img http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img',
      creates => '/tmp/cirros.img',
      before  => Glance_image['cirros'];
  }

  glance_image { 'cirros':
    ensure           => present,
    container_format => 'bare',
    disk_format      => 'qcow2',
    is_public        => 'yes',
    source           => '/tmp/cirros.img',
  }

  neutron_network { 'public':
    tenant_name               => 'openstack',
    router_external           => true,
    #provider_network_type     => 'flat',
    #provider_physical_network => 'eth2',
    shared                    => true,
  }
  Keystone_user_role['admin@openstack'] -> Neutron_network<||>

  neutron_subnet { 'public-subnet':
    cidr             => '10.156.0.0/14',
    ip_version       => '4',
    allocation_pools => ['start=10.158.20.10,end=10.158.20.100'],
    gateway_ip       => '10.159.255.254',
    enable_dhcp      => false,
    network_name     => 'public',
    tenant_name      => 'openstack',
  }

  neutron_network {
    'private':
      ensure      => present,
      tenant_name => 'openstack',
  }

  neutron_subnet {
    'private-subnet':
      cidr             => '192.168.1.0/24',
      ip_version       => '4',
      allocation_pools => ['start=192.168.1.10,end=192.168.1.100'],
      enable_dhcp      => true,
      network_name     => 'private',
      tenant_name      => 'openstack';
  }

  neutron_router { 'main_router':
    ensure               => present,
    tenant_name          => 'openstack',
    gateway_network_name => 'public',
    require              => Neutron_subnet['public-subnet'],
  }

  neutron_router_interface { 'main_router:private-subnet':
    ensure => present,
  }

  #include ::vswitch::ovs

  #vs_bridge { 'br-ex':
    #ensure => present,
    #notify => Exec['create_br-ex_vif'],
  #}

  # creates br-ex virtual interface to reach floating-ip network
  #exec { 'create_br-ex_vif':
    #path        => '/usr/bin:/bin:/usr/sbin:/sbin',
    #provider    => shell,
    #command     => 'ip addr add 10.158.20.1/22 dev br-ex; ip link set br-ex up',
    #refreshonly => true,
  #}


}
