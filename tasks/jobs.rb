# XP5K job
#
resources = [] << %{{type='kavlan-local'}/vlan=1+{ethnb='2'}/nodes=2+slash_22=1,walltime=#{XP5K::Config[:walltime]}}
roles = [
  XP5K::Role.new({
    name: 'puppetserver',
    size: 1
  }),
  XP5K::Role.new({
    name: 'controller',
    size: 1
  })
]

job_description = {
  resources:  resources,
  site:       XP5K::Config[:site],
  types:      ['deploy'],
  name:       XP5K::Config[:jobname],
  roles:      roles,
  command:    'sleep 186400'
}

job_description[:reservation] = XP5K::Config[:reservation] unless XP5K::Config[:reservation].nil?
xp.define_job(job_description)

# Job management tasks
#
namespace :grid5000 do

  desc 'Submit OAR jobs'
  task :jobs do
    xp.submit
    xp.wait_for_jobs
  end

  desc 'Get OAR jobs status'
  task :status do
    xp.status
  end

  desc 'Clean all OAR jobs'
  task :clean do
    puts "Clean all Grid'5000 running jobs..."
    xp.clean
  end

end
