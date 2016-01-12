# Module:: scenario
# Manifest:: openstack/mysql.pp
#

class scenario::openstack::mysql () {

  class { '::mysql::server': 
    override_options   => {
      'mysqld'         => {
        # TODO be more restrictive on the bind address ?
        'bind_address' => '0.0.0.0'
      },
      # restart mysql (because we change the bind address)
    },
    restart => true,
  }

}
