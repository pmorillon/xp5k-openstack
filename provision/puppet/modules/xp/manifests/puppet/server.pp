# Module:: xp
# Manifest:: puppet/server.pp
#

class xp::puppet::server {

  package {
    'openjdk-7-jre-headless':
      ensure => '7u51-2.4.6-1ubuntu4',
      before => Class['puppet::server']
  }

  class {
    '::puppet::server':
      puppetdb_terminus => true,
      reports           => 'store,puppetdb';
    '::puppet::puppetdb':
  }

  file {
    '/etc/puppetlabs/code/environments/production/modules-openstack':
      ensure => directory;
    '/etc/puppetlabs/code/environments/production/modules-scenario':
      ensure => directory;
    '/etc/puppetlabs/code/environments/production/manifests/site.pp':
      ensure  => file,
      content => 'hiera_include("classes")';
  }

  puppet::server::environment {
    'production':
      modulepath => './modules:./modules-openstack:./modules-scenario:$basemodulepath'
  }
}
