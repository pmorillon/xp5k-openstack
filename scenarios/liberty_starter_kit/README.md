# scenario : liberty_starter_kit

This scenario install Openstack Liberty on a single node with the following components :
* Keystone
* Glance
* Neutron
* Nova
* Horizon

__Notes__ : See _scenario::openstack_ Puppet class (`./puppet/modules/scenario/manifests/openstack.pp`) for details.

This scenario can be deployed on all Grid'5000 nodes supporting the hardware virtualization. Only one network interface is needed (See `./tasks/scenario.rb`).

## Openstack configuration

* By default 2 images are added to Glance :
  * [Cirros](http://download.cirros-cloud.net/0.3.4)
  * [Debian 8](http://cdimage.debian.org/cdimage/openstack/)
* A flavor `m1.xs` is created in order to use Debian 8 images.
* SSH and ICMP are allowed in the default security group.
* Network configuration :
  * Create __private__ and __public__ networks.
  * Create a __public__ subnet for floating IP's using reserved subnet.
  * Create a __private__ subnet for VM's local network.
  * Create a router __main_router__ using the reserved network as gateway and connected to the __private__ subnet.

__Notes__ : See `./tasks/scenario.rb`.
