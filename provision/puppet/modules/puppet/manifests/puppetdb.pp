# Module:: puppet
# Manifest:: puppetdb.pp
#

class puppet::puppetdb (
  String $version = "3.1.0-1puppetlabs1"
) {

  # Resources
  #
  package {
    'puppetdb':
      ensure => $version;
  }

  service {
    'puppetdb':
      ensure => running;
  }


  # Relations
  Package['puppetdb'] -> Service['puppetdb']

}
