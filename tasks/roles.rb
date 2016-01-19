# XP5K Roles
#
role 'all' do
  roles 'puppetserver'
end

namespace :roles do

  desc 'Show roles'
  task :show do
    XP5K::Role.list.each do |role|
      puts "* Role #{role.name} : #{role.servers.join(' ,')}"
    end
  end

end
