# Module:: puppet
# Manifest:: server.pp
#

class puppet::server (
  $dns_alt_names              = undef,
  Boolean $puppetdb_terminus  = false,
  String $puppetdb_server     = 'localhost',
  Integer $puppetdb_port      = 8081,
  $reports                    = undef,
  String $ca                  = 'enabled',
  Boolean $soft_write_failure = true
) {

  # Resources
  #
  # Todo: with puppetdb >= 3.0.0 use package puppetdb-termini instead of puppetdb-terminus.
  # Need to puppetdb compare version.
  package {
    'puppetserver':
      ensure => installed;
    'puppetdb-termini':
      ensure => $puppetdb_terminus ? {
        true    => installed,
        default => removed,
      };
  }

  service {
    'puppetserver':
      ensure => running;
  }

  augeas {
    'puppet_dns_alt_names':
      context => '/files/etc/puppetlabs/puppet/puppet.conf/master',
      changes => $dns_alt_names ? {
         undef   => "rm dns_alt_names",
         default => "set dns_alt_names $dns_alt_names",
      };
    'puppetdb_conf':
      incl    => '/etc/puppetlabs/puppet/puppetdb.conf',
      lens    => 'puppet.lns',
      changes => [
        "set /files/etc/puppetlabs/puppet/puppetdb.conf/main/server ${puppetdb_server}",
        "set /files/etc/puppetlabs/puppet/puppetdb.conf/main/port ${puppetdb_port}",
        "set /files/etc/puppetlabs/puppet/puppetdb.conf/main/soft_write_failure ${soft_write_failure}"
      ];
    'puppetdb_terminus':
      context => '/files/etc/puppetlabs/puppet/puppet.conf/master',
      changes => $puppetdb_terminus ? {
        true => [
          "set storeconfigs true",
          "set storeconfigs_backend puppetdb"
        ],
        default => ""
      };
    'puppet_reports':
      context => '/files/etc/puppetlabs/puppet/puppet.conf/master',
      changes => $reports ? {
         undef   => "rm reports",
         default => "set reports ${reports}",
      }
  }

  file {
    '/etc/puppetlabs/puppet/puppetdb.conf':
      ensure  => file,
      owner   => root,
      group   => root,
      mode    => '0644';
    '/etc/puppetlabs/puppet/routes.yaml':
      ensure  => file,
      owner   => puppet,
      group   => puppet,
      mode    => '0644',
      content => '
---
master:
  facts:
    terminus: puppetdb
    cache: yaml
';
  }


  case $ca {
    'enabled': {
      exec {
        'puppet_ca_enable_uncomment':
          command => "/bin/sed -i 's/^#puppetlabs.services.ca.certificate-authority-service/puppetlabs.services.ca.certificate-authority-service/g' /etc/puppetlabs/puppetserver/bootstrap.cfg",
          unless  => "/bin/grep -e '^puppetlabs.services.ca.certificate-authority-service' /etc/puppetlabs/puppetserver/bootstrap.cfg",
          tag     => 'ca';
      }

      exec {
        'puppet_ca_disable_comment':
          command => "/bin/sed -i 's/^puppetlabs.services.ca.certificate-authority-disabled-service/#puppetlabs.services.ca.certificate-authority-disabled-service/g' /etc/puppetlabs/puppetserver/bootstrap.cfg",
          unless  => "/bin/grep -e '^#puppetlabs.services.ca.certificate-authority-disabled-service' /etc/puppetlabs/puppetserver/bootstrap.cfg",
          tag     => 'ca';
      }
    }
    'disabled': {
      exec {
        'puppet_ca_enable_comment':
          command => "/bin/sed -i 's/^puppetlabs.services.ca.certificate-authority-service/#puppetlabs.services.ca.certificate-authority-service/g' /etc/puppetlabs/puppetserver/bootstrap.cfg",
          unless  => "/bin/grep -e '^#puppetlabs.services.ca.certificate-authority-service' /etc/puppetlabs/puppetserver/bootstrap.cfg",
          tag     => 'ca';
      }

      exec {
        'puppet_ca_disable_uncomment':
          command => "/bin/sed -i 's/^#puppetlabs.services.ca.certificate-authority-disabled-service/puppetlabs.services.ca.certificate-authority-disabled-service/g' /etc/puppetlabs/puppetserver/bootstrap.cfg",
          unless  => "/bin/grep -e '^puppetlabs.services.ca.certificate-authority-disabled-service' /etc/puppetlabs/puppetserver/bootstrap.cfg",
          tag     => 'ca';
      }
    }
    default: {
      err "ca property take only values : enabled, disabled"
    }
  }



  # Relations
  #
  Package['puppetserver'] -> Service['puppetserver']
  Package['puppetserver'] -> Augeas['puppet_dns_alt_names']
  Package['puppetserver'] -> File['/etc/puppetlabs/puppet/routes.yaml']
  Package['puppetserver'] -> Exec <| tag == 'ca' |>-> Service['puppetserver']
  File['/etc/puppetlabs/puppet/puppetdb.conf'] -> Augeas['puppetdb_conf']
  Augeas['puppet_dns_alt_names'] -> Service['puppetserver']
  Augeas['puppet_reports'] ~> Service['puppetserver']
  Augeas['puppetdb_terminus'] ~> Service['puppetserver']
  Augeas['puppetdb_conf'] ~> Service['puppetserver']

}
