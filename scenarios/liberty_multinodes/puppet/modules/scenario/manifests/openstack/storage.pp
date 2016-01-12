# Module:: scenario
# Manifest:: openstack/storage.pp
#

class scenario::openstack::storage (
  String $admin_password = $scenario::openstack::params::admin_password,
  String $controller_public_address = $scenario::openstack::params::controller_public_address
) inherits scenario::openstack::params {

  include ::glance
  include ::glance::backend::file
  include ::glance::client

  class { '::glance::api':
    debug               => true,
    verbose             => true,
    database_connection => "mysql://glance:glance@${controller_public_address}/glance?charset=utf8",
    keystone_password   => $admin_password,
    identity_uri        => "http://${controller_public_address}:35357",
    auth_uri            => "http://${controller_public_address}:5000",
    enabled             => true,
  }


  class { '::glance::registry':
    debug               => true,
    verbose             => true,
    database_connection => "mysql://glance:glance@${controller_public_address}/glance?charset=utf8",
    keystone_password   => $admin_password,
    identity_uri        => "http://${controller_public_address}:35357",
    auth_uri            => "http://${controller_public_address}:5000",
  }

  class { '::glance::notify::rabbitmq':
    rabbit_userid       => 'glance',
    rabbit_password     => 'an_even_bigger_secret',
    rabbit_host         => $controller_public_address,
    notification_driver => 'messagingv2',
  }

}
