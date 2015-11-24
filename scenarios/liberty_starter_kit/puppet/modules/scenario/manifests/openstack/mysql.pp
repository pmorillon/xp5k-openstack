# Module:: scenario
# Manifest:: openstack/mysql.pp
#

class scenario::openstack::mysql {

  class { '::mysql::server': }

}
