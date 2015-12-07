# XP5K deployment
#
@deployment_def = {
  site:        XP5K::Config[:site],
  environment: 'ubuntu-x64-1404',
  jobs:        [XP5K::Config[:jobname]],
  key:         File.read(XP5K::Config[:public_key])
}

@deployment_def[:notifications] = ["xmpp:#{XP5K::Config[:user]}@jabber.grid5000.fr"] if XP5K::Config[:notification]


# Deployment management tasks
#
namespace :grid5000 do

  desc 'Submit Kadeploy environment deployment'
  task :deploy do
    xp.deploy
  end

end
