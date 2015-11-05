# Module:: puppet
# Manifest:: agent.pp
#

class puppet::agent (
  String $server = 'puppet',
  String $ca_server = 'puppet',
  String $runinterval = '1h',
  String $environment = 'production',
  Boolean $running = false
) {

  # Resources
  #
  service {
    'puppet':
      ensure => $running ? {
        true    => running,
        default => stopped
      };
  }

  augeas {
    'puppet_agent':
      context => '/files/etc/puppetlabs/puppet/puppet.conf/main',
      changes => [
        "set server ${server}",
        "set ca_server ${server}",
        "set runinterval ${runinterval}",
        "set environment ${environment}"
      ];
  }

}
