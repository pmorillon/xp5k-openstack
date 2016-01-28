# Module:: scenario
# Manifest:: openstack/param.pp
#

class scenario::openstack::params {

  $admin_password = 'admin'

  $controller_public_address = hiera("scenario::openstack::controller_public_address")
  $storage_public_address = hiera("scenario::openstack::storage_public_address")

  $public_network = hiera("scenario::openstack::public_network")
  $data_network = hiera("scenario::openstack::data_network")


  case $::osfamily {
    'Debian': {
      include ::apt
      class { '::openstack_extras::repo::debian::ubuntu':
        release         => 'liberty',
        repo            => 'proposed',
        package_require => true,
      }
      $package_provider = 'apt'
    }
    'RedHat': {
      class { '::openstack_extras::repo::redhat::redhat':
        manage_rdo => false,
        repo_hash  => {
          'openstack-common-testing'  => {
            'baseurl'  => 'http://cbs.centos.org/repos/cloud7-openstack-common-testing/x86_64/os/',
            'descr'    => 'openstack-common-testing',
            'gpgcheck' => 'no',
          },
          'openstack-liberty-testing' => {
            'baseurl'  => 'http://cbs.centos.org/repos/cloud7-openstack-liberty-testing/x86_64/os/',
            'descr'    => 'openstack-liberty-testing',
            'gpgcheck' => 'no',
          },
          'openstack-liberty-trunk'   => {
            'baseurl'  => 'http://trunk.rdoproject.org/centos7-liberty/current/',
            'descr'    => 'openstack-liberty-trunk',
            'gpgcheck' => 'no',
          },
        },
      }
      package { 'openstack-selinux': ensure => 'latest' }
      $package_provider = 'yum'
    }
    default: {
      fail("Unsupported osfamily (${::osfamily})")
    }
  }


}
