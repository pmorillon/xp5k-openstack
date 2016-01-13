# Definitions
#
def upload_bootstrap_env(host)
  sh %{rm -rf /tmp/xp5k_$USER/xp5k-openstack/bootstrap}
  sh %{mkdir -p /tmp/xp5k_$USER/xp5k-openstack/bootstrap/{hieradata,modules}}
  sh %{rsync -a --delete provision/puppet/modules/ /tmp/xp5k_$USER/xp5k-openstack/bootstrap/modules }
  sh %{rsync -a --delete scenarios/#{XP5K::Config[:scenario]}/hiera/generated/ /tmp/xp5k_$USER/xp5k-openstack/bootstrap/hieradata }
  sh %{cd /tmp/xp5k_$USER/xp5k-openstack && tar -cf - bootstrap/ | ssh#{SSH_CONFIGFILE_OPT} root@#{host} 'cd /etc/puppetlabs/code/environments && tar xf -'}
end


# Puppet tasks
#
namespace :puppet do

  namespace :agent do

    desc 'Install Puppet agent package on all nodes'
    task :install do
      on(roles('all'), user: 'root') do
        repo_pkg, agent_pkg_name = case XP5K::Config[:puppet_release]
          when 3 then
            ['puppetlabs-release-trusty.deb', 'puppet']
          when 4 then
            ['puppetlabs-release-pc1-trusty.deb', 'puppet-agent']
          else
            raise "Puppet release #{XP5K::Config[:puppet_release]} not supported."
        end
        url = "http://apt.puppetlabs.com/#{repo_pkg}"
        cmd = [] << "wget -q #{url} && dpkg -i #{repo_pkg}"
        cmd << "rm #{repo_pkg}"
        cmd << "apt-get update && apt-get install -y lsb-release #{agent_pkg_name}"
        cmd << "echo '' > /etc/environment"
      end
    end

    desc "Puppet Puppet agent on node host=<role|FQDN>"
    task :run => ['puppet:modules:upload'] do
      hosts = parse_host()
      puppetserver = roles('puppetserver').first
      on hosts, :user => 'root' do
        cmd = "/opt/puppetlabs/bin/puppet agent -t --server #{puppetserver}"
        cmd += " --debug" if ENV['debug']
        cmd += " --trace" if ENV['trace']
        cmd
      end
    end
  end

  namespace :server do

    desc 'bootstrap Puppet server'
    task :bootstrap do
      puppetserver_fqdn = roles('puppetserver').first
      upload_bootstrap_env(puppetserver_fqdn)
      on(puppetserver_fqdn, user: 'root') do
        "/opt/puppetlabs/bin/puppet apply --environment bootstrap -e 'include xp,xp::locales,xp::puppet::server'"
      end
    end

  end

  namespace :modules do
    desc 'Download external openstack Puppet modules'
    task :get do
      ENV['PUPPETFILE'] = "scenarios/#{XP5K::Config[:scenario]}/Puppetfile"
      ENV['PUPPETFILE_DIR'] = "scenarios/#{XP5K::Config[:scenario]}/puppet/modules-openstack"
      unless File.exists?(ENV['PUPPETFILE_DIR'])
        sh %{r10k puppetfile install -v}
      else
        puts "** Module directory #{ENV['PUPPETFILE_DIR']} already exists."
      end
    end

    desc 'Delete external Puppet modules'
    task :remove do
      sh "rm -rf scenarios/#{XP5K::Config[:scenario]}/puppet/modules-openstack"
    end

    desc 'Upload Puppet modules and hiera database'
    task :upload => [:get, 'puppet:hiera:generate'] do
      puppetserver_fqdn = roles('puppetserver').first
      sh %{cd provision/puppet/modules && tar -cf - . | ssh#{SSH_CONFIGFILE_OPT} root@#{puppetserver_fqdn} 'cd /etc/puppetlabs/code/environments/production/modules && tar xf -'}
      sh %{cd scenarios/#{XP5K::Config[:scenario]}/puppet/modules-openstack && tar -cf - . | ssh#{SSH_CONFIGFILE_OPT} root@#{puppetserver_fqdn} 'cd /etc/puppetlabs/code/environments/production/modules-openstack && tar xf -'}
      sh %{cd scenarios/#{XP5K::Config[:scenario]}/puppet/modules && tar -cf - . | ssh#{SSH_CONFIGFILE_OPT} root@#{puppetserver_fqdn} 'cd /etc/puppetlabs/code/environments/production/modules-scenario && tar xf -'}
      sh %{cd scenarios/#{XP5K::Config[:scenario]}/hiera/generated && tar -cf - . | ssh#{SSH_CONFIGFILE_OPT} root@#{puppetserver_fqdn} 'cd /etc/puppetlabs/code/environments/production/hieradata && tar xf -'}
    end
  end


  namespace :hiera do
    desc 'Generate hiera database'
    task :generate do
      templates_dir = "scenarios/#{XP5K::Config[:scenario]}/hiera/templates"
      generated_dir = "scenarios/#{XP5K::Config[:scenario]}/hiera/generated"
      if File.exists?(generated_dir)
        rm_rf generated_dir
        mkdir_p generated_dir + "/nodes"
      else
        mkdir_p generated_dir + "/nodes"
      end
      XP5K::Role.list.each do |role|
        if File.exists?(templates_dir + "/nodes/#{role.name}.yaml")
          role.servers.each do |server|
            cp "#{templates_dir}/nodes/#{role.name}.yaml", "#{generated_dir}/nodes/#{server}.yaml"
          end
        end
      end
      cp "#{templates_dir}/common.yaml", "#{generated_dir}/"
      puppetserver = roles('puppetserver').first
      node = YAML.load_file("scenarios/#{XP5K::Config[:scenario]}/hiera/generated/nodes/#{puppetserver}.yaml")
      node['puppet::server::autosign'] = roles('all')
      File.open("scenarios/#{XP5K::Config[:scenario]}/hiera/generated/nodes/#{puppetserver}.yaml", 'w') do |file|
        file.puts node.to_yaml
      end
    end
  end

end
