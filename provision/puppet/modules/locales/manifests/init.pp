# Module:: locales
# Manifest:: init.pp
#

class locales (
  $lang     = 'en_US.UTF-8',
  $language = 'en_US:en',
  $lc_all   = 'en_US.UTF-8'
) inherits locales::params {

  # Resources
  #
  package {
    $locales::params::package_name:
      ensure => installed;
  }

  file {
    $locales::params::config_file_path:
      content => template('locales/default.erb');
  }


  # Relations
  #
  Package[$locales::params::package_name] -> File[$locales::params::config_file_path]

}
