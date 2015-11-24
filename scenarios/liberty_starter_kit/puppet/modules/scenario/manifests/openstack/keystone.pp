# Module:: scenario
# Manifest:: openstack/keystone.pp
#

class scenario::openstack::keystone (
  String $admin_password = $scenario::openstack::params::admin_password
) inherits scenario::openstack::params {

  class { '::keystone::client': }
  class { '::keystone::cron::token_flush': }
  class { '::keystone::db::mysql':
    password => 'keystone',
  }
  class { '::keystone':
    verbose             => true,
    debug               => true,
    database_connection => 'mysql://keystone:keystone@127.0.0.1/keystone',
    admin_token         => 'admin_token',
    enabled             => true,
    service_name        => 'httpd',
    default_domain      => 'default_domain',
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
  }

}
