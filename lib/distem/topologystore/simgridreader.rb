require 'rexml/document'

module Distem
  module TopologyStore

    # Class that allow to load a configuration from an XML simgrid input. See "http://simgrid.gforge.inria.fr/files/simgrid.dtd" for more information about the input format. FIXME: document each method to explain how the translation is done
    class SimgridReader < TopologyReader
      IPHACKROOT='10.144'
      @@iphack = 0

      # Create a new SimgridReader specifying the path to an image (see Resource::FileSystem) to use for the virtual nodes
      # ==== Attributes
      # * +image+ The path to a -compressed and bootstrapped- image (String)
      #
      def initialize(image)
        super()
        @image = image
      end

      # Parse a simgrid XML string value that represents the virtual environment.
      # ==== Attributes
      # * +inputstr+ The simgrid XML input (String)
      # ==== Returns
      # Hash object that describes the platform (see Lib::Validator)
      #
      def parse(inputstr)
        result = {}
        xmldoc = REXML::Document.new(inputstr)
        result = parse_platform(xmldoc,result)
        return result
      end

      # Parse the <platform> XML field. All the "parse_" methods are working the same way, parsing the associated XML field that represents a simgrid resource.
      # ==== Attributes
      # * +xmldoc+ The REXML::Element object that describes the field
      # * +result+ The Hash output result to write the result to
      # * +tmp+ An object used to pass arguments through the methods
      # ==== Returns
      # Hash object that describes the virtual platform (see Lib::Validator)
      # 
      def parse_platform(xmldoc,result,tmp={})
        raise Lib::NotImplementedError unless xmldoc.root.attributes['version'] == '2'
        result['vplatform'] = {}
        result['vplatform']['vnodes'] = []
        result['vplatform']['vnetworks'] = []

        # Create all the nodes contained in a cluster
        xmldoc.elements.each("*/cluster") do |cluster|
          parse_cluster(cluster,result['vplatform'],tmp)
        end

        # Create virtual switchss (VNodes in gateway mode)
        xmldoc.elements.each("*/link") do |cluster|
          parse_link(cluster,result['vplatform'],tmp)
        end

        # Connect virtual switches
        xmldoc.elements.each("*/link") do |cluster|
          parse_switch(cluster,result['vplatform'],tmp)
        end

        # Connect the networks to the switches
        xmldoc.elements.each("*/route:multi") do |cluster|
          parse_route_multi(cluster,result['vplatform'],tmp)
        end

        return result
      end

      # See the parse_platform method documentation
      def parse_cluster(xmldoc,result,tmp={})
        netname = xmldoc.attribute('id').to_s
        result['vnetworks'] << {
          'name' => netname,
          'address' => "#{IPHACKROOT}.#{@@iphack}.0/24"
        }
        @@iphack += 1

        vnode = nil
        create_vnode = Proc.new {
          vnode = {
            'name' => nil,
            'vifaces' => [{
              'name' => 'if0',
              'vnetwork' => netname,
              'vinput' => nil,
              'voutput' => {
                'direction' => 'OUTPUT',
                'properties' => [
                  { 'type' => 'bandwidth', 'rate' => xmldoc.attribute('bw').to_s.to_f.to_s + 'bps' },
                  { 'type' => 'latency', 'delay' => xmldoc.attribute('lat').to_s.to_f.to_s + 's' },
                ]
              }
            }],
            'vfilesystem' =>  {
              'image' => @image,
              'shared' => true
            }
          }
        }

        create_vnode.call
        defaultgw = vnode
        defaultgw['name'] = netname + '_gw'
        defaultgw['vifaces'][0]['voutput'] = nil
        defaultgw['gateway'] = true
        result['vnodes'] << defaultgw

        tmp['gateways'] = [] unless tmp['gateways']
        gw = {
          'name' => defaultgw['name'],
          'bw' => nil,
          'lat' => nil,
          'ifnb' => 1
        }
        tmp['gateways'] << gw
        tmp['networks'] = [] unless tmp['networks']
        tmp['networks'] << {
          'name' => netname,
          'defaultgw' => gw,
        }


        lbound,ubound = xmldoc.attribute('radical').to_s.split('-')
        (lbound..ubound).each do |no|
          create_vnode.call
          vnode['name'] = xmldoc.attribute('prefix').to_s + no.to_s + xmldoc.attribute('sufix').to_s
          result['vnodes'] << vnode
        end

      end

      # See the parse_platform method documentation
      def parse_link(xmldoc,result,tmp={})
        switch = xmldoc.attribute('sharing_policy')
        if switch and switch.to_s == 'FATPIPE'
          nodename = xmldoc.attribute('id').to_s
          result['vnodes'] << {
            'name' => nodename,
            'vifaces' => [],
            'gateway' => true,
            'vfilesystem' => {
              'image' => @image,
              'shared' => true
            }
          }
          tmp['switches'] = [] unless tmp['switches']
          tmp['switches'] << { 
            'name' => nodename,
            'bw' => xmldoc.attribute('bandwidth').to_s.to_f.to_s + 'bps',
            'lat' => xmldoc.attribute('latency').to_s.to_f.to_s + 's',
            'ifnb' => 0,
          }
        end
      end

      # See the parse_platform method documentation
      def parse_switch(xmldoc,result,tmp={})
        return nil unless tmp['switches']
        completename = xmldoc.attribute('id').to_s
        name1,name2 = completename.split('_')
        switch1 = tmp['switches'].select{ |switch| switch['name'].split('_sw')[0] == name1 }[0]
        switch2 = tmp['switches'].select{ |switch| switch['name'].split('_sw')[0] == name2 }[0]
        if switch1 and switch2
          bw = xmldoc.attribute('bandwidth').to_s.to_f.to_s + 'bps'
          lat = xmldoc.attribute('latency').to_s.to_f.to_s + 's'

          # Create vnetwork
          result['vnetworks'] << {
            'name' => completename,
            'address' => "#{IPHACKROOT}.#{@@iphack}.0/24"
          }
          @@iphack += 1

          switch = {}
          block = Proc.new {
            vnode = result['vnodes'].select{ |node| node['name'] == switch['name'] }[0]
            vnode['vifaces'] << {
              'name' => 'if' + switch['ifnb'].to_s,
              'vnetwork' => completename,
              'vinput' => nil,
              'voutput' => {
                'direction' => 'OUTPUT',
                'properties' => [
                  { 'type' => 'bandwidth', 'rate' => bw },
                  { 'type' => 'latency', 'delay' => lat },
                ]
              }
            }
            switch['ifnb'] += 1
          }
          # Connect switch1 to network
          switch = switch1
          block.call
          # Connect switch2 to network
          switch = switch2
          block.call
        end
      end

      # See the parse_platform method documentation
      def parse_route_multi(xmldoc,result,tmp={})
        srcnetstr = xmldoc.attribute('src').to_s
        dstnetstr = xmldoc.attribute('dst').to_s

        # >>> TODO: Create VRoute with dst instead of using vroutes_complete
        srcnet = tmp['networks'].select{ |net| net['name'] == srcnetstr }[0]
        dstnet = tmp['networks'].select{ |net| net['name'] == dstnetstr }[0]
        if srcnet
          cnt = 0
          elems = []
          switches = false
          elems << srcnet['defaultgw']
          xmldoc.elements.each('link:ctn') do |link|
            ret = parse_link_ctn(link,result,tmp)
            if ret == true
              cnt += 1
            elsif ret.is_a?(Hash)
              switches = true
              elems << ret
            end
          end
          elems << dstnet['defaultgw'] if dstnet

          elem = {}
          network1 = ''
          network2 = ''
          connect_elem = Proc.new {
            vnode = result['vnodes'].select{ |node| node['name'] == elem['name'] }[0]
            if network1 < network2
              networkname = network2 + '-' + network1
            else
              networkname = network1 + '-' + network2
            end

            # Create vnetwork
            newnet = result['vnetworks'].select { |net| net['name'] == networkname }
            if !newnet or newnet.empty?
              result['vnetworks'] << {
                'name' => networkname,
                'address' => "#{IPHACKROOT}.#{@@iphack}.0/24"
              }
              @@iphack += 1
            end

            # Create viface
            viface = vnode['vifaces'].select{ |iface| iface['vnetwork'] == networkname }[0]
            unless viface
              viface = {
                'name' => 'if' + elem['ifnb'].to_s,
                'vnetwork' => networkname,
                'vinput' => nil,
              }

              if elem['lat'] or elem['bw']
                viface['voutput'] = {
                  'direction' => 'OUTPUT',
                  'properties' => [
                    { 'type' => 'bandwidth', 'rate' => elem['bw'] },
                    { 'type' => 'latency', 'delay' => elem['lat'] },
                  ]
                }
              else
                viface['voutput'] = nil
              end

              vnode['vifaces'] << viface
              elem['ifnb'] += 1
            end
          }

          if cnt == 1 or switches
            (1..(elems.size-1)).each do |i|
              network1 = elems[i-1]['name']
              network2 = elems[i]['name']
              elem = elems[i-1]
              connect_elem.call
              elem = elems[i]
              connect_elem.call
            end
          end

        end
      end

      # See the parse_platform method documentation
      def parse_link_ctn(xmldoc,result,tmp)
        name = xmldoc.attribute('id').to_s
        switch = tmp['switches'].select{ |sw| sw['name'] == name }[0] if tmp['switches']
        ret = true
        if switch
          ret = switch
        elsif name == '$dst'
          ret = false
        else
          ret = true
        end
        return ret
      end

      protected

      # Connect a virtual node to a virtual network
      def self.connect_vnode(result,gw,vnodename,vnetworkname) 
        vnode = result['vnodes'].select{ |node| node['name'] == switch['name'] }[0]
        viface = {
          'name' => 'if' + switch['ifnb'].to_s,
          'vnetwork' => vnetworkname,
          'vinput' => nil,
          'voutput' => {
            'direction' => 'OUTPUT',
            'properties' => [
              { 'type' => 'bandwidth', 'rate' => switch['bw'] },
              { 'type' => 'latency', 'delay' => switch['lat'] },
            ]
          }
        }
        switch['ifnb'] += 1
        vnode['vifaces'] << viface
      end
    end

  end
end
