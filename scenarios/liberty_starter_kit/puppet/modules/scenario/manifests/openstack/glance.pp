# Module:: scenario
# Manifest:: openstack/glance.pp
#

class scenario::openstack::glance (
  String $admin_password = $scenario::openstack::params::admin_password
) inherits scenario::openstack::params {

  class { '::glance::db::mysql':
    password => 'glance',
  }

  file {
    '/tmp/glance':
      ensure  => directory,
      owner   => glance,
      group   => glance,
      require => Package['glance-api'];
    '/tmp/glance/images':
      ensure  => directory,
      owner   => glance,
      group   => glance,
      require => File['/tmp/glance'];
  }

  include ::glance
  include ::glance::client

  class {
    '::glance::backend::file':
      filesystem_store_datadir => '/tmp/glance/images',
      require                  => File['/tmp/glance/images'];
  }

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

  class { '::glance::notify::rabbitmq':
    rabbit_userid       => 'glance',
    rabbit_password     => 'an_even_bigger_secret',
    rabbit_host         => '127.0.0.1',
    notification_driver => 'messagingv2',
  }

}
