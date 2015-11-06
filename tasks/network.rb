# Network tasks
#

namespace :network do

  desc 'Set secondary interface into reserved VLAN'
  task :vlan do
    servers = roles('controller', 'computes')
    vlanid = xp.job_with_name(XP5K::Config[:jobname])['resources_by_type']['vlans'].first.to_i
    root = xp.connection.root.sites[XP5K::Config[:site].to_sym]
    vlan = root.vlans.find { |item| item['uid'] == vlanid.to_s }
    # TODO: checks API to determinate secondary interface
    interfaces = servers.map { |server| server.gsub(/-(\d+)/, '-\1-' + 'eth1') }
    puts "** Set in vlan #{vlanid} following interfaces : #{interfaces}..."
    vlan.submit :nodes => interfaces
  end

end
