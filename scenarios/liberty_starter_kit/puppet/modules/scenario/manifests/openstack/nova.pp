# Module:: scenario
# Manifest:: openstack/nova.pp
#

class scenario::openstack::nova (
  String $admin_password = $scenario::openstack::params::admin_password
) inherits scenario::openstack::params {

  class {
    '::nova::db::mysql':
      password => 'nova',
  }

  class {
    '::nova::keystone::auth':
      password => $admin_password,
  }

  class {
    '::nova':
      database_connection => 'mysql://nova:nova@127.0.0.1/nova?charset=utf8',
      rabbit_host         => '127.0.0.1',
      rabbit_userid       => 'nova',
      rabbit_password     => 'an_even_bigger_secret',
      glance_api_servers  => 'localhost:9292',
      verbose             => true,
      debug               => true,
  }

  class {
    '::nova::api':
      admin_password                       => $admin_password,
      identity_uri                         => 'http://127.0.0.1:35357/',
      osapi_v3                             => true,
      neutron_metadata_proxy_shared_secret => 'a_big_secret',
  }

  class { '::nova::cert': }
  class { '::nova::client': }
  class { '::nova::conductor': }
  class { '::nova::consoleauth': }
  class { '::nova::cron::archive_deleted_rows': }

  class {
    '::nova::compute':
      #vnc_keymap  => 'fr',
      vnc_enabled => true;
  }

  class { '::nova::compute::libvirt':
    libvirt_virt_type => 'qemu',
    migration_support => true,
    vncserver_listen  => '0.0.0.0',
  }
  class { '::nova::scheduler': }
  class { '::nova::vncproxy': }
  class { '::nova::network::neutron':
    neutron_admin_password => $admin_password,
    neutron_admin_auth_url => 'http://127.0.0.1:35357/v2.0',
  }

  class { 'memcached':
    listen_ip => '127.0.0.1',
    tcp_port  => '11211',
    udp_port  => '11211',
  }

  class { '::horizon':
    cache_server_ip    => '127.0.0.1',
    cache_server_port  => '11211',
    secret_key         => '12345',
    #  swift           => false,
    django_debug       => 'True',
    api_result_limit   => '2000',
    vhost_extra_params =>  { 'port' => '8080' };
  }


}
