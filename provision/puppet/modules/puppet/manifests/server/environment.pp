# Module:: puppet
# Manifest:: server/environment.pp
#

define puppet::server::environment (
  String $modulepath = './modules:$basemodulepath'
) {

  file {
    "/etc/puppetlabs/code/environments/${name}":
      ensure => directory;
    "/etc/puppetlabs/code/environments/${name}/environment.conf":
      ensure  => file,
      content => template('puppet/server/environment.conf.erb');
  }

}
