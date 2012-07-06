require 'distem'


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
        raise "A churn event must take an 'up' or 'down' value" if (@change_type == 'churn' and @event_value != 'up' and @event_value != 'down')
        raise "The direction of the viface must be 'input' or 'output'" if @resource_desc['viface_direction'] and @resource_desc['viface_direction'] != 'output' and @resource_desc['viface_direction'] != 'input'

      end

      def trigger(event_list = nil, date = 0)

        cl = NetAPI::Client.new
        desc = {}
        if @change_type == 'churn'
          if @resource_desc['type'] == 'vnode'
            if @event_value == 'up'
              cl.vnode_start(@resource_desc['vnodename'])
            else
              cl.vnode_shutdown(@resource_desc['vnodename'])
            end
          else
            raise "Not implemented (yet?) : #{@change_type} on #{@resource_desc['type']}"
          end

        elsif @change_type == 'power'
          cl.vcpu_update(@resource_desc['vnodename'], @event_value)

        elsif @change_type == 'bandwidth'
          # If no unit is given, we assume the value is in Mbps
          @event_value = "#{@event_value}mbps" unless @event_value.is_a?(String) and @event_value.include?('s')
          if @resource_desc['viface_direction']
            desc[@resource_desc['viface_direction']] = { 'bandwidth' => { 'rate' => @event_value } }
          else
            desc['input'] = { 'bandwidth' => { 'rate' => @event_value } }
            desc['output'] = { 'bandwidth' => { 'rate' => @event_value } }
          end
          cl.viface_update(@resource_desc['vnodename'], @resource_desc['vifacename'], desc)

        elsif @change_type == 'latency'
          # If no unit is given, we assume the value is in milliseconds
          @event_value = "#{@event_value}ms" unless @event_value.is_a?(String) and @event_value.include?('s')
          if @resource_desc['viface_direction']
            desc[@resource_desc['viface_direction']] = { 'latency' => { 'delay' => @event_value } }
          else
            desc['input'] = { 'latency' => { 'delay' => @event_value } }
            desc['output'] = { 'latency' => { 'delay' => @event_value } }
          end
          cl.viface_update(@resource_desc['vnodename'], @resource_desc['vifacename'], desc)

        else
          raise "Not implemented : #{@change_type}"
        end
      end

      # Must be implemented to sort events in the list, if their dates are equal
      def <=>(other_event)
        # How do we order events ? I don't know either, so no order !
        return 0
      end

    end

  end
end
