# Module:: xp
# Manifest:: puppet/server.pp
#

class xp::puppet::server {

  class {
    '::puppet::server':
      puppetdb_terminus => true,
      reports           => 'store,puppetdb';
    '::puppet::puppetdb':
  }

}
