

module Distem
  module Events

    class Event

      def initialize(resource_desc, change_type, event_value)

        @resource_desc = resource_desc
        @change_type = change_type
        @event_value = event_value

        raise "No viface name given" if @resource_desc['type']=='viface' and not @resource_desc['vifacename']
        raise "Resource power change must be applied on a vcpu,not a #{@resource_desc['type']}" if @change_type == 'power' and @resource_desc['type'] != 'vcpu'
        raise "Bandwith or latency power change must be applied on a viface,not a #{@resource_desc['type']}" if (@change_type == 'bandwith' or  @change_type == 'latency') and @resource_desc['type'] != 'viface'
        raise "Churn cannot be applied on a vcpu" if (@change_type == 'churn' and @resource_desc['type'] == 'vcpu')
        raise "A churn event must take an 'up' or 'down' value" if (@change_type == 'churn' and @event_value != 'up' and @event_value != 'down' and @event_value != 'freeze' and @event_value != 'unfreeze')
        raise "The direction of the viface must be 'input' or 'output'" if @resource_desc['viface_direction'] and @resource_desc['viface_direction'] != 'output' and @resource_desc['viface_direction'] != 'input'

      end

      def trigger(event_list = nil, date = 0)
        # All that stuff will be launch in a thread
        runblock = Proc.new {
          cl = NetAPI::Client.new

          if @change_type == 'churn'
            if @resource_desc['type'] == 'vnode'
              case @event_value
              when 'up'
                cl.vnode_start(@resource_desc['vnodename'])
              when 'down'
                cl.vnode_stop(@resource_desc['vnodename'])
              when 'freeze'
                cl.vnode_freeze(@resource_desc['vnodename'])
              when 'unfreeze'
                cl.vnode_unfreeze(@resource_desc['vnodename'])
              end
            else
              raise "Not implemented (yet?) : #{@change_type} on #{@resource_desc['type']}"
            end

          elsif @change_type == 'power'
            if @event_value.to_f > 1
              cl.vcpu_update(@resource_desc['vnodename'], @event_value, 'mhz')
            else
              cl.vcpu_update(@resource_desc['vnodename'], @event_value, 'ratio')
            end
          elsif (@change_type == 'bandwidth' or @change_type == 'latency')
            # we must get the previous state
            desc = { 'input' => {}, 'output' => {} }
            vnode_desc = cl.vnode_info(@resource_desc['vnodename'])
            vnode_desc['vifaces'].each do |viface_desc|
              if viface_desc['name'] == @resource_desc['vifacename']
                if viface_desc['output'] and @resource_desc['viface_direction'] and @resource_desc['viface_direction']=='output'
                  desc['output'] = viface_desc['output']
                end

                if viface_desc['input'] and @resource_desc['viface_direction'] and @resource_desc['viface_direction']=='input'
                  desc['input'] = viface_desc['input']
                end
              end
            end

            if @change_type == 'bandwidth'
              # If no unit is given, we assume the value is in Mbps
              @event_value = "#{@event_value}mbps" unless @event_value.is_a?(String) and @event_value.include?('s')
              if @resource_desc['viface_direction']
                desc[@resource_desc['viface_direction']] = { 'bandwidth' => { 'rate' => @event_value } }
                desc.delete_if { |direction, property| direction != @resource_desc['viface_direction'] }
              else
                desc['input']['bandwidth'] = { 'rate' => @event_value }
                desc['output']['bandwidth'] = { 'rate' => @event_value }
              end

            else # latency change
              # If no unit is given, we assume the value is in milliseconds
              @event_value = "#{@event_value}ms" unless @event_value.is_a?(String) and @event_value.include?('s')
              if @resource_desc['viface_direction']
                desc[@resource_desc['viface_direction']] = { 'latency' => { 'delay' => @event_value } }
                desc.delete_if { |direction, property| direction != @resource_desc['viface_direction'] }
              else
                desc['input']['latency'] = { 'delay' => @event_value }
                desc['output']['latency'] = { 'delay' => @event_value }
              end
            end

            cl.viface_update(@resource_desc['vnodename'], @resource_desc['vifacename'], desc)

          else
            raise "Not implemented : #{@change_type}"
          end
        }
        tid = Thread.new {
          runblock.call
        }
        tid.abort_on_exception=true

      end

      # Must be implemented to sort events in the list, if their dates are equal
      def <=>(other_event)
        # How do we order events ? I don't know either, so no order !
        return 0
      end

    end

  end
end
