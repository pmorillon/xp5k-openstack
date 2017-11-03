# Scenario dedicated Rake task
#
#

# Override OAR resources (tasks/jobs.rb)
# We uses 2 nodes (1 puppetserver and 1 controller) and a subnet for floating public IPs
#
XP5K::Config[:jobname]    ||= '[openstack]liberty_multinode'
XP5K::Config[:site]       ||= 'rennes'
XP5K::Config[:walltime]   ||= '1:00:00'
XP5K::Config[:cluster]    ||= ''
XP5K::Config[:vlantype]   ||= 'kavlan-local'
XP5K::Config[:computes]   ||= 1
XP5K::Config[:interfaces] ||= 1

oar_cluster = ""
oar_cluster = "and cluster='" + XP5K::Config[:cluster] + "'" if !XP5K::Config[:cluster].empty?
# vlan reservation 
# the first interface is put in the production network
# the other ones are put a dedicated vlan thus we need #interfaces - 1 vlans
oar_vlan = ""
oar_vlan = "{type='#{XP5K::Config[:vlantype]}'}/vlan=#{XP5K::Config[:interfaces] - 1}" if XP5K::Config[:interfaces] >= 2

nodes = 4 + XP5K::Config[:computes].to_i

resources = [] << 
[ 
  "#{oar_vlan}",
  "{eth_count >= #{XP5K::Config[:interfaces]} and virtual != 'none' #{oar_cluster}}/nodes=#{nodes}",
  "slash_22=1, walltime=#{XP5K::Config[:walltime]}"
].join("+")

@job_def[:resources] = resources
@job_def[:roles] << XP5K::Role.new({
  name: 'controller',
  size: 1
})

@job_def[:roles] << XP5K::Role.new({
  name: 'storage',
  size: 1
})

@job_def[:roles] << XP5K::Role.new({
  name: 'network',
  size: 1
})

@job_def[:roles] << XP5K::Role.new({
  name: 'compute',
  size: XP5K::Config[:computes].to_i
})

G5K_NETWORKS = YAML.load_file("scenarios/liberty_multinodes/g5k_networks.yml")

# Override role 'all' (tasks/roles.rb)
#
role 'all' do
  roles 'puppetserver', 'controller', 'storage', 'network', 'compute'
end

# Define OAR job (required)
#
xp.define_job(@job_def)


# Define Kadeploy deployment (required)
#
xp.define_deployment(@deployment_def)


namespace :scenario do

  desc 'Main task called at the end of `run` task'
  task :main do
    # install vlan (force cache regeneration before)
    Rake::Task['interfaces:cache'].execute
    Rake::Task['interfaces:vlan'].execute
    Rake::Task['scenario:hiera:update'].execute
    
    # patch 
    Rake::Task['scenario:os:patch'].execute
    Rake::Task['puppet:modules:upload'].execute

    # run controller recipes 
    # do not call rake task (due to chaining)
    puppetserver = roles('puppetserver').first
    on roles('controller') do
        cmd = "/opt/puppetlabs/bin/puppet agent -t --server #{puppetserver}"
        cmd += " --debug" if ENV['debug']
        cmd += " --trace" if ENV['trace']
        cmd
    end
    
    on roles('network', 'storage', 'compute') do
        cmd = "/opt/puppetlabs/bin/puppet agent -t --server #{puppetserver}"
        cmd += " --debug" if ENV['debug']
        cmd += " --trace" if ENV['trace']
        cmd
    end

    Rake::Task['scenario:bootstrap'].execute
  end
  
  desc 'Bootstrap the installation' 
  task :bootstrap do
    workflow = [
      'scenario:os:fix_proxy',
      'scenario:os:rules',
      'scenario:os:public_bridge',
      'scenario:os:network',
      'scenario:os:horizon',
      'scenario:os:flavors',
      'scenario:os:images'
    ]
    workflow.each do |task|
      Rake::Task[task].execute
    end
 end
  

  namespace :hiera do

    desc 'update common.yaml with network information (controller/storage ips, networks adresses)'
    task :update do
      update_common_with_networks()
      # upload the new common.yaml
      puppetserver_fqdn = roles('puppetserver').first
      sh %{cd scenarios/#{XP5K::Config[:scenario]}/hiera/generated && tar -cf - . | ssh#{SSH_CONFIGFILE_OPT} root@#{puppetserver_fqdn} 'cd /etc/puppetlabs/code/environments/production/hieradata && tar xf -'}
    end
  end

  namespace :os do

    desc 'Update default security group rules'
    task :fix_proxy do
      on(roles('controller'), user: 'root') do
        cmd = 'rm -f /etc/environment'
      end
    end

    desc 'Update default security group rules'
    task :rules do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        # Add SSH rule
        cmd = [] << 'nova secgroup-add-rule default tcp 22 22 0.0.0.0/0'
        # Add ICMP rule
        cmd << 'nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0'
        cmd
      end
    end

    desc 'Configure public bridge'
    task :public_bridge do
      on(roles('network'), user: 'root') do
        interfaces = get_node_interfaces
        network = roles('network').first
        device = interfaces[network]["public"]["device"]
        %{ ovs-vsctl add-port br-ex #{device} && ip addr flush #{device} && dhclient -nw br-ex }
      end
    end

    desc 'Configure Openstack network'
    task :network do

      publicSubnet = G5K_NETWORKS[XP5K::Config[:site]]["subnet"]
      reservedSubnet = xp.job_with_name(XP5K::Config[:jobname])['resources_by_type']['subnets'].first
      publicPool = IPAddr.new(reservedSubnet).to_range.to_a[10..100]
      publicPoolStart,publicPoolStop = publicPool.first.to_s,publicPool.last.to_s
      privateCIDR = '192.168.1.0/24'
      privatePool = IPAddr.new(privateCIDR).to_range.to_a[10..100]
      privatePoolStart,privatePoolStop = privatePool.first.to_s,privatePool.last.to_s

      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        cmd = []
        cmd << %{neutron net-create public --shared --provider:physical_network external --provider:network_type flat --router:external True}
        cmd << %{neutron net-create private}
        cmd << %{neutron subnet-create public #{publicSubnet["cidr"]} --name public-subnet --allocation-pool start=#{publicPoolStart},end=#{publicPoolStop} --dns-nameserver 131.254.203.235 --gateway #{publicSubnet["gateway"]}  --disable-dhcp}
        cmd << %{neutron subnet-create private #{privateCIDR} --name private-subnet --allocation-pool start=#{privatePoolStart},end=#{privatePoolStop} --dns-nameserver 131.254.203.235} 
        cmd << %{neutron router-create main_router}
        cmd << %{neutron router-gateway-set main_router public}
        cmd << %{neutron router-interface-add main_router private-subnet}
        cmd
      end
    end

    desc 'Init horizon theme'
    task :horizon do
      on(roles('controller'), user: 'root') do
        %{/usr/share/openstack-dashboard/manage.py collectstatic --noinput && /usr/share/openstack-dashboard/manage.py compress --force}
      end
    end

    desc 'Get images'
    task :images do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        [
           %{/usr/bin/wget -q -O /tmp/cirros.img http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img},
           %{glance image-create --name="Cirros" --disk-format=qcow2 --container-format=bare --property architecture=x86_64 --progress --file /tmp/cirros.img},
           %{/usr/bin/wget -q -O /tmp/debian.img http://public.rennes.grid5000.fr/openstack/debian-8.3.0-openstack-amd64.qcow2},
           %{glance image-create --name="Debian Jessie 64-bit" --disk-format=qcow2 --container-format=bare --property architecture=x86_64 --progress --file /tmp/debian.img}
        ]
      end
    end

    desc 'Add flavors'
    task :flavors do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        %{nova flavor-create m1.xs auto 2048 6 2 --is-public True}
      end
    end

    desc 'Patch horizon Puppet module'
    task :patch do
      os = %x[uname].chomp
      case os
      when 'Linux'
        sh %{sed -i '24s/apache2/httpd/' scenarios/#{XP5K::Config[:scenario]}/puppet/modules-openstack/horizon/manifests/params.pp}
        sh %{sed -i 's/F78372A06FF50C80464FC1B4F7B8CEA6056E8E56/0A9AF2115F4687BD29803A206B73A36E6026DFCA/' scenarios/#{XP5K::Config[:scenario]}/puppet/modules-openstack/rabbitmq/manifests/repo/apt.pp}
      when 'Darwin'
        sh %{sed -i '' '24s/apache2/httpd/' scenarios/#{XP5K::Config[:scenario]}/puppet/modules-openstack/horizon/manifests/params.pp}
        sh %{sed -i '' 's/F78372A06FF50C80464FC1B4F7B8CEA6056E8E56/0A9AF2115F4687BD29803A206B73A36E6026DFCA/' scenarios/#{XP5K::Config[:scenario]}/puppet/modules-openstack/rabbitmq/manifests/repo/apt.pp}
      else
        puts "Patch not applied."
      end
    end


  end

end

def update_common_with_networks
  interfaces = get_node_interfaces
  common = YAML.load_file("scenarios/#{XP5K::Config[:scenario]}/hiera/generated/common.yaml")
  common['scenario::openstack::admin_password'] = XP5K::Config[:openstack_env][:OS_PASSWORD]

  common = YAML.load_file("scenarios/#{XP5K::Config[:scenario]}/hiera/generated/common.yaml")
  vlanids = xp.job_with_name("#{XP5K::Config[:jobname]}")['resources_by_type']['vlans']

  controller = roles('controller').first
  common['scenario::openstack::controller_public_address'] = interfaces[controller]["public"]["ip"]
  storage = roles('storage').first
  common['scenario::openstack::storage_public_address'] = interfaces[storage]["public"]["ip"]

  # each specific OpenStack network is picked in the reserved vlan
  # if the number of interfaces is sufficient
  # TODO handle more than 1 vlan 
  # 1 for management (in this implementation management is the same as public)
  # 1 for data 
  ['data_network'].each_with_index do |network, i| 
    if (XP5K::Config[:interfaces] > 1)
     common["scenario::openstack::#{network}"] = G5K_NETWORKS[XP5K::Config[:site]]["vlans"][vlanids[i % vlanids.size].to_i]
    else
     common["scenario::openstack::#{network}"] = G5K_NETWORKS[XP5K::Config[:site]]["production"]
    end
  end

  common['scenario::openstack::public_network'] = G5K_NETWORKS[XP5K::Config[:site]]["production"]

  File.open("scenarios/#{XP5K::Config[:scenario]}/hiera/generated/common.yaml", 'w') do |file|
    file.puts common.to_yaml
  end
end
