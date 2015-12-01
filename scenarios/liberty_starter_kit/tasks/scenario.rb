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
      'scenario:os:public_bridge',
      'scenario:os:horizon',
      'scenario:os:flavors',
      'scenario:os:images'
    ]
    workflow.each do |task|
      Rake::Task[task].execute
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
           %{/usr/bin/wget -q -O /tmp/debian.img http://cdimage.debian.org/cdimage/openstack/8.2.0/debian-8.2.0-openstack-amd64.qcow2},
           %{glance image-create --name="Debian Jessie 64-bit" --disk-format=qcow2 --container-format=bare --property architecture=x86_64 --progress --file /tmp/debian.img}
        ]
      end
    end

    desc 'Add flavors'
    task :flavors do
      on(roles('controller'), user: 'root', environment: XP5K::Config[:openstack_env]) do
        %{nova flavor-create m1.xs auto 2048 4 2 --is-public True}
      end
    end

  end

end
