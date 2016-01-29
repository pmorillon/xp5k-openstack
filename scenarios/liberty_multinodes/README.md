# scenario : liberty_multinodes

This scenario install Openstack Liberty on multiple nodes using the following topology.

* 1 Controller node --- hosts core services, MySQL database and RabbitMQ
* 1 Storage node --- hosts glance service
* 1 Network node --- hosts the cloud router
* n compute nodes --- host virtual servers


Nodes         | Description         | Puppet recipe
--------------|-------------------- | -------------
Controller    | Core services       | `puppet/modules/scenario/manifests/controller.pp`
Storage       | Glance API + backend| `puppet/modules/scenario/manifests/storage.pp`
Network       | Routing node        | `puppet/modules/scenario/manifests/network.pp`
Compute       | Hypervisor          | `puppet/modules/scenario/manifests/compute.pp`

__Notes__ :

This scenario can be deployed on nodes having **two network interfaces**. One is used for API
communication with Openstack (tagged public interface in the puppet code), the other
is used for VM traffic communication (tagged private interface in the puppet code).

## Optionnal ```xp.conf``` parameters

The following parameters are optionnal in the ```xp.conf``` file. If some are not set,
default values will bet set for them (see ```tasks/scenario.rb```). Here is an example :

```
cluster    'parasilo'
vlantype   'kavlan'
computes   3
interfaces 2
```

__Notes__ :  

* The total number of nodes used by the deployment is ```computes + 4```
* The number of interfaces to use can be set to 1 or 2 (values above aren't supported) yet : using 1 interface allows you to deploy anywhere on Grid'5000. When using two interfaces the second one will be use for intra-vm communication and will be set on a dedicated vlan.



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
