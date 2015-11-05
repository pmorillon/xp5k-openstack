# Module:: locales
# Manifest:: params.pp
#

class locales::params {

  case $::osfamily {
    'Debian': {
      $package_name = 'locales'
      $config_file_path = '/etc/default/locale'
    }
    default: {
      fail "OS family ${::osfamily} is not supported"
    }
  }

}
