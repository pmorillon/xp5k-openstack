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
     
      # Those interfaces will be put in a dedicated vlan
      private_interfaces = restfullyDatas['network_adapters'].select{ |na| 
        na['interface'] == 'Ethernet' && na['mountable'] && ( not na['mounted'])
      }
      public_interface = restfullyDatas['network_adapters'].select{ |na| 
        na['interface'] == 'Ethernet' && na['mountable'] && na['mounted']
      }.first

      interfaceMapping[node] = {
        "public" => {
          "device" => public_interface["device"],
          "ip"     => public_interface["ip"],
      },
        "private" => private_interfaces.map{|p| {
          "device" => p["device"] 
        }}
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

  # it is assumed that all the nodes have the same number of reserved devices
  desc 'Put second, third  interfaces in the reserved vlan'
  task :vlan do
    # get the vlan id
    vlanids = xp.job_with_name("#{XP5K::Config[:jobname]}")['resources_by_type']['vlans']
    if (vlanids.nil? or vlanids.empty?)
      # no vlan, moving to the next task
      next
    end

    # mapping between nodes and their interfaces (mountable)
    nodesInterfaces = get_node_interfaces
    # holds the node names required to submit into a vlan
    # ex [paranoia-1-eth2, parvance-1-eth1, ...]
    nodesApiVlan = Hash.new {|h,k| h[k] = []} 
    # holds the mapping nodeName -> device
    interfaceMapping = Hash.new {|h,k| h[k] = []} 

    nodesInterfaces.each do |node, devices|
      # private interfaces will be set in the vlan
      nodeName = node.split('.').first
      private_devices =  devices['private']
      private_devices.each_with_index do |priv, di|
        index = di % vlanids.size
        nodesApiVlan[vlanids[index].to_i] << "#{nodeName}-#{priv["device"]}.#{XP5K::Config[:site]}.grid5000.fr"
        interfaceMapping[node] << priv["device"]
        # keep track of the vlanid associated with this device
        priv["vlanid"] = vlanids[index]
      end
    end
    update_interfaces(nodesInterfaces)
    # example nodesApiVlan (2 vlans 4 and 5):  
    # 4 => [parapluie-1-eth1.rennes.grid5000.fr, parapluie-2-eth1.rennes.grid5000.fr],
    # 5 => [parapluie-3-eth2.rennes.grid5000.fr, parapluie-4-eth2.rennes.grid5000.fr]
    #
    root = xp.connection.root.sites[XP5K::Config['site'].to_sym]
    nodesApiVlan.each do |vlanid, nodes| 
      vlan = root.vlans.find { |item| item['uid'] == vlanid.to_s }
      puts ({:nodes => nodes}).inspect
      vlan.submit :nodes => nodes
    end

    interfaceMapping.each do |node, devices|
      devices.each do |device| 
        # TODO open only one connection to renew the all the leases 
        # of a given node
         on(node) do 
          "dhclient -nw  #{device}"
        end
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

