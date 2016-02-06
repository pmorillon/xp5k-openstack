# Module:: scenario
# Manifest:: openstack/keystone.pp
#

class scenario::openstack::keystone (
  String $admin_password = $scenario::openstack::params::admin_password,
  String $controller_public_address = $scenario::openstack::params::controller_public_address,
) inherits scenario::openstack::params {

  class { '::keystone::client': }
  class { '::keystone::cron::token_flush': }
  class { '::keystone::db::mysql':
    password => 'keystone',
    allowed_hosts => ['localhost', '127.0.0.1', '%']
  }
  class { '::keystone':
    verbose             => true,
    debug               => true,
    database_connection => 'mysql+pymysql://keystone:keystone@127.0.0.1/keystone',
    admin_token         => 'admin_token',
    enabled             => true,
    service_name        => 'httpd',
    #    default_domain      => 'default_domain',
  }
  include ::apache
  class { '::keystone::wsgi::apache':
    ssl => false,
  }
  class { '::keystone::roles::admin':
    email    => 'test@example.tld',
    password => $admin_password,
  }
  class { '::keystone::endpoint':
    default_domain => 'admin',
    public_url   => "http://${controller_public_address}:5000",
    internal_url => "http://${controller_public_address}:5000",
    admin_url    => "http://${controller_public_address}:35357"
  }

  /**
  * Force the creation of the _member_ role
  * see https://github.com/pmorillon/xp5k-openstack/issues/4
  */
  keystone_role { '_member_':
    ensure => present,
  }

}
