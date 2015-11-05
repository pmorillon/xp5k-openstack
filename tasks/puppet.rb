# Puppet tasks
#
namespace :puppet do

  namespace :agent do

    desc 'Install Puppet agent package on all nodes'
    task :install do
      on(roles('all'), user: 'root') do

        # Puppet 3 installation
        repo_pkg, agent_pkg_name = 'puppetlabs-release-trusty.deb', 'puppet'

        # Puppet 4 installation
        #repo_pkg, agent_pkg_name = 'puppetlabs-release-pc1-trusty.deb', 'puppet-agent'

        url = "http://apt.puppetlabs.com/#{repo_pkg}"
        url, agent_pkg_name = "http://apt.puppetlabs.com/#{repo_pkg}", 'puppet'
        cmd = [] << "http_proxy=http://proxy:3128 wget -q #{url} && dpkg -i #{repo_pkg}"
        cmd << "apt-get update && apt-get install -y lsb-release #{agent_pkg_name}"
        cmd << "rm #{repo_pkg}"
      end
    end
  end

  namespace :server do

    desc 'Install Puppet server'
    task :install do
      on(roles('puppetserver'), user: 'root') do
        'hostname && date && uptime'
      end
    end
  end

end
