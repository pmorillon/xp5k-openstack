# Definitions
#
def upload_bootstrap_env(host)
  sh %{cd provision/puppet && tar -cf - . | ssh#{SSH_CONFIGFILE_OPT} root@#{host} 'mkdir -p /etc/puppetlabs/code/environments/bootstrap && cd /etc/puppetlabs/code/environments/bootstrap && tar xvf -'}
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
        cmd = [] << "http_proxy=http://proxy:3128 wget -q #{url} && dpkg -i #{repo_pkg}"
        cmd << "apt-get update && apt-get install -y lsb-release #{agent_pkg_name}"
        cmd << "rm #{repo_pkg}"
      end
    end
  end

  namespace :server do

    desc 'Install Puppet server'
    task :install do
      puppetserver_fqdn = roles('puppetserver').first
      upload_bootstrap_env(puppetserver_fqdn)
      on(puppetserver_fqdn, user: 'root') do
        "/opt/puppetlabs/bin/puppet apply --environment bootstrap -e 'include xp::locales,xp::puppet::server'"
      end
    end
  end

end
