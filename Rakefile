# Rakefile
# Rakefile for Openstack deployment on Grid5000
#

require 'xp5k'
require 'xp5k/rake'
require 'hiera'


# Constants
#
SSH_CONFIGFILE_OPT = XP5K::Config[:ssh_config].nil? ? "" : " -F " + XP5K::Config[:ssh_config]


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
    'puppet:server:bootstrap',
    'puppet:hiera:generate',
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

