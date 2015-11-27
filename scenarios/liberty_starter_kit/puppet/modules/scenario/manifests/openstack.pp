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
  class { 'scenario::openstack::horizon': }

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

}
