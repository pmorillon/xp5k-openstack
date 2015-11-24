# Module:: scenario
# Manifest:: openstack/glance.pp
#

class scenario::openstack::glance (
  String $admin_password = $scenario::openstack::params::admin_password
) inherits scenario::openstack::params {

  class { '::glance::db::mysql':
    password => 'glance',
  }

  include ::glance
  include ::glance::backend::file
  include ::glance::client

  class { '::glance::keystone::auth':
    password => $admin_password,
  }

  class { '::glance::api':
    debug               => true,
    verbose             => true,
    database_connection => 'mysql://glance:glance@127.0.0.1/glance?charset=utf8',
    keystone_password   => $admin_password,
    enabled             => true,
  }

  class { '::glance::registry':
    debug               => true,
    verbose             => true,
    database_connection => 'mysql://glance:glance@127.0.0.1/glance?charset=utf8',
    keystone_password   => $admin_password,
  }

}
