# Scenario dedicated Rake task
#

namespace :scenario do

  desc 'Main task called at the end of `run` task'
  task :main do
    ENV['host'] = 'controller'
    Rake::Task['scenario:hiera:update'].execute
    Rake::Task['puppet:agent:run'].execute
    workflow = [
      'scenario:os:rules',
      'scenario:os:public_bridge'
    ]
    workflow.each do |task|
      Rake::Task[task].execute
    end
  end

  namespace :network do

    desc 'Set secondary interface into reserved VLAN'
    task :vlan do
      servers = roles('controller')
      vlanid = xp.job_with_name(XP5K::Config[:jobname])['resources_by_type']['vlans'].first.to_i
      root = xp.connection.root.sites[XP5K::Config[:site].to_sym]
      vlan = root.vlans.find { |item| item['uid'] == vlanid.to_s }
      # TODO: checks API to determinate secondary interface
      interfaces = servers.map { |server| server.gsub(/-(\d+)/, '-\1-' + 'eth1') }
      puts "** Set in vlan #{vlanid} following interfaces : #{interfaces}..."
      vlan.submit :nodes => interfaces
    end

  end

  namespace :hiera do

    desc 'Update hiera'
    task :update do
      controller = roles('controller').first
      node = YAML.load_file("scenarios/#{XP5K::Config[:scenario]}/hiera/generated/nodes/#{controller}.yaml")
      node['scenario::openstack::admin_password'] = XP5K::Config[:openstack_env][:OS_PASSWORD]
      File.open("scenarios/#{XP5K::Config[:scenario]}/hiera/generated/nodes/#{controller}.yaml", 'w') do |file|
        file.puts node.to_yaml
      end
    end

  end

  namespace :os do

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
      on(roles('controller'), user: 'root') do
        %{ ovs-vsctl add-port br-ex eth0 && ip addr flush eth0 && dhclient -nw br-ex }
      end
    end

    desc 'Configure Openstack network'
    task :network do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        cmd = []
        cmd << %{neutron net-create public --shared --provider:physical_network external --provider:network_type flat --router:external True}
        cmd << %{neutron net-create private}
        cmd << %{neutron subnet-create public 10.156.0.0/14 --name public-subnet --allocation-pool start=10.158.20.10,end=10.158.20.100 --dns-nameserver 172.16.111.118 --gateway 10.159.255.254  --disable-dhcp}
        cmd << %{neutron subnet-create private 192.168.1.0/24 --name private-subnet --allocation-pool start=192.168.1.10,end=192.168.1.100}
        cmd << %{neutron router-create main_router}
        cmd << %{neutron router-gateway-set main_router public}
        cmd << %{neutron router-interface-add main_router private-subnet}
        cmd
      end
    end

  end

end
