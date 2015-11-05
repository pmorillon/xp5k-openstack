# Module:: puppet
# Manifest:: augeas.pp
#

class puppet::augeas {

  include 'augeas'


  # Resources
  #
  package {
    'ruby-augeas':
      ensure => installed;
  }

}
