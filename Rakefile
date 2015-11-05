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
XP5K::Config[:scenario]     ||= 'starter_kit'
XP5K::Config[:walltime]     ||= '1:00:00'
XP5K::Config[:user]         ||= ENV['USER']
XP5K::Config[:computes]     ||= 1
XP5K::Config[:notification] ||= false


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


# Meta task
#
desc 'Start Openstack deployment'
task :run do
  workflow = [
    'grid5000:jobs',
    'grid5000:deploy',
    'puppet:agent:install',
    'puppet:server:install'
  ]
  workflow.each do |task|
    Rake::Task[task].execute
  end
end

