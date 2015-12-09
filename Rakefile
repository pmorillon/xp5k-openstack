# Rakefile
# Rakefile for Openstack deployment on Grid5000
#

require 'xp5k'
require 'xp5k/rake'
require 'hiera'
require 'ipaddr'


# Constants
#
SSH_CONFIGFILE_OPT = XP5K::Config[:ssh_config].nil? ? "" : " -F " + XP5K::Config[:ssh_config]
G5K_SUBNETS = {
  rennes: { cidr: '10.156.0.0/14', gateway: '10.159.255.254' },
  nantes: { cidr: '10.176.0.0/14', gateway: '10.179.255.254' },
  lille: { cidr: '10.136.0.0/14', gateway: '10.139.255.254' },
  reims: { cidr: '10.168.0.0/14', gateway: '10.171.255.254' },
  nancy: { cidr: '10.144.0.0/14', gateway: '10.147.255.254' },
  luxembourg: { cidr: '10.172.0.0/14', gateway: '10.175.255.254' },
  lyon: { cidr: '10.140.0.0/14', gateway: '10.143.255.254' },
  grenoble: { cidr: '10.132.0.0/14', gateway: '10.135.255.254' },
  sophia: { cidr: '10.164.0.0/14', gateway: '10.167.255.254' },
}


# Load ./xp.conf file
#
XP5K::Config.load


# Initialize experiment
#
@xp = XP5K::XP.new()
def xp; @xp; end


# Defaults configuration
#
XP5K::Config[:scenario]       ||= 'liberty_starter_kit'
XP5K::Config[:walltime]       ||= '1:00:00'
XP5K::Config[:user]           ||= ENV['USER']
XP5K::Config[:computes]       ||= 1
XP5K::Config[:notification]   ||= false
XP5K::Config[:jobname]        ||= 'xp5k_openstack'
XP5K::Config[:puppet_release] ||= 4
XP5K::Config[:site]           ||= 'rennes'

XP5K::Config[:openstack_env]  ||= {
  OS_USERNAME: 'admin',
  OS_PASSWORD: 'admin',
  OS_TENANT_NAME: 'openstack',
  OS_AUTH_URL: 'http://127.0.0.1:5000/v2.0'
}


# Definitions
#
# Parse host environment var
def parse_host
  args = ENV['host'].split(',')
  hosts = []
  args.each do |arg|
    if XP5K::Role.listnames.include? arg
      hosts << roles(arg)
    else
      hosts << arg
    end
  end
  hosts.flatten
end


# Load Rake tasks
#
Dir["tasks/*.rb"].each do |taskfile|
  load taskfile
end


# Load scenario dedicated Rake tasks
#
Dir["scenarios/#{XP5K::Config[:scenario]}/tasks/*.rb"].each do |taskfile|
  load taskfile
end


# Meta task
#
desc 'Start Openstack deployment'
task :run do
  workflow = [
    'grid5000:jobs',
    'grid5000:deploy',
    'puppet:agent:install',
    'puppet:hiera:generate',
    'puppet:server:bootstrap',
    'puppet:modules:get',
    'puppet:modules:upload'
  ]
  workflow.each do |task|
    Rake::Task[task].execute
  end
  ENV['host'] = 'puppetserver'
  Rake::Task['puppet:agent:run'].execute
  Rake::Task['scenario:main'].execute
end

