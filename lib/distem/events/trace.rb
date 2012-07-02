require 'distem'


module Distem
  module Events

    # Event trace
    class Trace

      # Array of all event associate to this trace - format : [[ date, event ], ... ]
      attr_reader :event_list

      def initialize
      end

      def add_event_list(event_list)
        @event_list += event_list
        @event_list.sort!
      end

      def add_event(date, event)
        raise unless (event.is_a?(Event) and date.is_a?(Numeric)
        add_event_list([[date, event]])
      end

      def pop_next_event
        return @event_list.delete(0)
      end

    end

  end
end
