
class scenario::openstack::controller(
  String $package_provider = $scenario::openstack::params::package_provider,
  String $admin_password = $scenario::openstack::params::admin_password,
  String $controller_public_address = $scenario::openstack::params::controller_public_address,
  String $storage_public_address = $scenario::openstack::params::storage_public_address,
) inherits scenario::openstack::params {

  class { 'scenario::openstack::mysql':}
  class { 'scenario::openstack::rabbitmq': }
  class { 'scenario::openstack::horizon': }

  class {
    'scenario::openstack::keystone':
      admin_password             => $admin_password,
      controller_public_address  => $controller_public_address,
  }

  # Glance (controller side)
  class { '::glance::db::mysql':
    password      => 'glance',
    # TODO be more restrictive on the grants
    allowed_hosts => ['localhost', '127.0.0.1', '%']
  }

 class { '::glance::keystone::auth':
    password     => $admin_password,
    public_url   => "http://${storage_public_address}:9292",
    internal_url => "http://${storage_public_address}:9292",
    admin_url    => "http://${storage_public_address}:9292"
  }


  # Neutron (controller side)
  class { '::neutron::db::mysql':
    password => 'neutron',
    # TODO be more restrictive on the grants
    allowed_hosts => ['localhost', '127.0.0.1', '%']
  }
  class { '::neutron::keystone::auth':
    password => $admin_password,
    public_url   => "http://${controller_public_address}:9696",
    internal_url => "http://${controller_public_address}:9696",
    admin_url    => "http://${controller_public_address}:9696"
  }
  
  # common config between neutron and computes
  class {'::scenario::common::neutron':
    controller_public_address => $controller_public_address
  }

  class { '::neutron::client': }
  class { '::neutron::server':
    database_connection => "mysql://neutron:neutron@${controller_public_address}/neutron?charset=utf8",
    auth_password       => $admin_password,
    identity_uri        => "http://${controller_public_address}:35357/",
    auth_uri            => "http://${controller_public_address}:5000",
    sync_db             => true,
  }

  class { '::neutron::server::notifications':
    username    => 'nova',
    tenant_name => 'services',
    password    => $admin_password,
    nova_url    => "http://${controller_public_address}:8774/v2",
    auth_url    => "http://${controller_public_address}:35357",
    region_name => "RegionOne"
  }


  # Nova (controller side)
  class {
    '::nova::db::mysql':
      password => 'nova',
      # TODO be more restrictive on the grants
      allowed_hosts => ['localhost', '127.0.0.1', '%']
  }

  # common config between controller and computes
  class { '::scenario::common::nova': 
    controller_public_address => $controller_public_address,
    storage_public_address    => $storage_public_address
  }

  class {
    '::nova::keystone::auth':
      password => $admin_password,
      public_url   => "http://${controller_public_address}:8774/v2/%(tenant_id)s",
      internal_url   => "http://${controller_public_address}:8774/v2/%(tenant_id)s",
      admin_url   => "http://${controller_public_address}:8774/v2/%(tenant_id)s"
  }

  class {
    '::nova::api':
      admin_password                       => $admin_password,
      identity_uri                         => "http://${controller_public_address}:35357/",
      osapi_v3                             => true,
      neutron_metadata_proxy_shared_secret => $admin_password,
  }

  class { '::nova::scheduler': }
  class { '::nova::cert': }
  class { '::nova::conductor': }
  class { '::nova::consoleauth': }
  class { '::nova::vncproxy':
    host        => $controller_public_address,
    enabled => true,
  }

  # rc file for the admin
  class { '::openstack_extras::auth_file':
    tenant_name => 'openstack',
    password    => $admin_password,
    # /root/openrc is checked and if it exists leads to some error
    # on puppet runs (cannot find suitable plugin URL...)
    path        => '/root/adminrc'
  }

}
