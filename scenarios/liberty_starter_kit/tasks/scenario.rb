# Scenario dedicated Rake task
#

# Override OAR resources (tasks/jobs.rb)
# We uses 2 nodes (1 puppetserver and 1 controller) and a subnet for floating public IPs
#
resources = [] << %{{virtual='ivt'}/nodes=2+slash_22=1,walltime=#{XP5K::Config[:walltime]}}
@job_def[:resources] = resources
@job_def[:roles] << XP5K::Role.new({
  name: 'controller',
  size: 1
})


# Override role 'all' (tasks/roles.rb)
#
role 'all' do
  roles 'puppetserver', 'controller'
end


# Define OAR job (required)
#
xp.define_job(@job_def)


# Define Kadeploy deployment (required)
#
xp.define_deployment(@deployment_def)


namespace :scenario do

  # Required task
  desc 'Main task called at the end of `run` task'
  task :main do
    ENV['host'] = 'controller'
    Rake::Task['scenario:hiera:update'].execute
    Rake::Task['scenario:os:patch'].execute
    Rake::Task['puppet:modules:upload'].execute
    Rake::Task['puppet:agent:run'].execute
    workflow = [
      'scenario:os:rules',
      'scenario:os:public_bridge',
      'scenario:os:horizon',
      'scenario:os:flavors',
      'scenario:os:images',
      'scenario:os:network',
      'scenario:horizon_access'
    ]
    workflow.each do |task|
      Rake::Task[task].execute
    end
  end

  desc 'Show SSH configuration to access Horizon'
  task :horizon_access do
    puts '** Launch this script on your local computer and open http://localhost:8080 on your navigator'
    puts '---'
    script = %{cat > /tmp/openstack_ssh_config <<EOF\n}
    script += %{Host *.grid5000.fr\n}
    script += %{  User #{ENV['USER']}\n}
    script += %{  ProxyCommand ssh -q #{ENV['USER']}@194.254.60.4 nc -w1 %h %p # Access South\n}
    script += %{EOF\n}
    script += %{ssh -F /tmp/openstack_ssh_config -N -L 8080:#{roles('controller').first}:8080 #{ENV['USER']}@frontend.#{XP5K::Config[:site]}.grid5000.fr &\n}
    script += %{HTTP_PID=$!\n}
    script += %{ssh -F /tmp/openstack_ssh_config -N -L 6080:#{roles('controller').first}:6080 #{ENV['USER']}@frontend.#{XP5K::Config[:site]}.grid5000.fr &\n}
    script += %{CONSOLE_PID=$!\n}
    script += %{trap 'kill -9 $HTTP_PID && kill -9 $CONSOLE_PID' 2\n}
    script += %{http://localhost:8080\n}
    script += %{wait\n}
    puts script
    puts '---'
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
      controllerHostname = roles('controller').first.split('.').first
      clusterName = controllerHostname.split('-').first
      restfullyDatas = xp.connection.root
      .sites[XP5K::Config[:site].to_sym]
      .clusters[clusterName.to_sym]
      .nodes.select { |i| i['uid'] == controllerHostname }.first
      device = restfullyDatas['network_adapters'].select { |interface|
        interface['mounted'] == true
      }.first['device']
      on(roles('controller'), user: 'root') do
        %{ ovs-vsctl add-port br-ex #{device} && ip addr flush #{device} && dhclient -nw br-ex }
      end
    end

    desc 'Configure Openstack network'
    task :network do
      publicSubnet = G5K_SUBNETS[XP5K::Config[:site].to_sym]
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
        cmd << %{neutron subnet-create public #{publicSubnet[:cidr]} --name public-subnet --allocation-pool start=#{publicPoolStart},end=#{publicPoolStop} --dns-nameserver $(gethostip -d dns) --gateway #{publicSubnet[:gateway]}  --disable-dhcp}
        cmd << %{neutron subnet-create private #{privateCIDR} --name private-subnet --allocation-pool start=#{privatePoolStart},end=#{privatePoolStop}}
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

    desc 'Patch horizon Puppet module'
    task :patch do
      sh %{sed -i '' '24s/apache2/httpd/' scenarios/liberty_starter_kit/puppet/modules-openstack/horizon/manifests/params.pp}
    end

  end

end
