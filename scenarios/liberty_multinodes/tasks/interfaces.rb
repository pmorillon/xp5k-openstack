# vlans tasks
# ... and node descrption caching logic
# ... for each relevant node we store some information from the API 
# ... -> e.g eth# may varies from cluster to cluster so we aren't
# ... allways sure that the second interface is eth1 (on paranoia it's eth2) 
# ... TODO this cachinf logic should probably go directly to xp5k

INTERFACES_CACHE="scenarios/liberty_multinodes/.interfaces.yml"

def get_nodes
  nodes = []
  xp.roles.each do |r|
    nodes << r.servers
  end
  nodes = nodes.flatten 
end

def generate_interfaces_cache
    # holds the node names required to submit into a vlan
    # ex [paranoia-1-eth2, parvance-1-eth1, ...]

    # holds the mapping nodeName -> [device1, device2, ...] 
    # only mountable interfaces are listed
    interfaceMapping = {}
    get_nodes.each do |node|
      # in the api we have paranoia-1 instead of paranoia-1.rennes.grid5000.fr as node uid
      # get the first interface mountable but not mounted
      nodeName = node.split('.').first
      clusterName = nodeName.split('-').first
      restfullyDatas = xp.connection
        .root
        .sites[XP5K::Config[:site].to_sym]
        .clusters[clusterName.to_sym]
        .nodes.select { |n| n['uid'] == nodeName }.first
      
      private_interface = restfullyDatas['network_adapters'].select{ |interface| 
        interface['mountable'] && ( not interface['mounted'])
      }.first
      public_interface = restfullyDatas['network_adapters'].select{ |interface| 
        interface['mountable'] && interface['mounted']
      }.first

      interfaceMapping[node] = {
        "public" => {"device" => public_interface["device"], "ip" => public_interface["ip"] },
        "private" => {"device" => private_interface["device"]},
      }

    end
    File.open(INTERFACES_CACHE, 'w') {|f| f.write interfaceMapping.to_yaml }
end

def get_node_interfaces
  generate_interfaces_cache unless File.exist?(INTERFACES_CACHE)
  interfaces = YAML.load_file(INTERFACES_CACHE)
  return interfaces
end

def update_interfaces(interfaces)
    File.open(INTERFACES_CACHE, 'w') {|f| f.write interfaces.to_yaml }
end

# put the second interface in the vlan...
# second means the first interface that is not mounted but mountable
namespace :interfaces do

  desc 'cache interfaces information'
  task :cache do
    # force the creation of the cache
    generate_interfaces_cache
  end

  desc 'Put second interface in the reserved vlan'
  task :vlan do
    # mapping between nodes and their interfaces (mountable)
    nodesInterfaces = get_node_interfaces
    # holds the node names required to submit into a vlan
    # ex [paranoia-1-eth2, parvance-1-eth1, ...]
    nodesApiVlan = []
    # holds the mapping nodeName -> device
    interfaceMapping = {}

    nodesInterfaces.each do |node, devices|
      # private interface will be set in the vlan
      nodeName = node.split('.').first
      device =  devices['private']['device']
      nodesApiVlan << "#{nodeName}-#{device}.#{XP5K::Config[:site]}.grid5000.fr"
      interfaceMapping[node] = device
    end
    # get the vlan id
    vlanid = xp.job_with_name("#{XP5K::Config[:jobname]}")['resources_by_type']['vlans'].first.to_i
    # put nodes in vlan
    root = xp.connection.root.sites[XP5K::Config['site'].to_sym]
    vlan = root.vlans.find { |item| item['uid'] == vlanid.to_s }
    puts nodesApiVlan.inspect
    vlan.submit :nodes => nodesApiVlan

    # restart interfaces on the vlan
    interfaceMapping.each do |node, device|
      on(node) do 
        "dhclient -nw  #{device}"
      end
    end
  end

end
# append to clean the removal of interface cache file 
# INTERFACES_CAHE is defined in tasks/interfaces.rb
namespace :grid5000 do
  desc 'remove interfaces cache file'
  task :clean do
    puts "Removing interface cache file..."
    rm INTERFACES_CACHE unless File.exist?(INTERFACES_CACHE)
  end

end

