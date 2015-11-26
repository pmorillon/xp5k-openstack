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

}
