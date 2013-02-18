

module Distem
  module Events

    # Event trace
    class Trace

      # Array of all event associate to this trace - format : [[ date, event ], ... ]
      attr_reader :event_list

      def initialize
        @event_list = []
        @mutex = Mutex.new
      end

      def add_event_list(event_list)
        @mutex.synchronize do
          @event_list += event_list
          @event_list.sort!
        end
      end

      def add_event(date, event)
        raise "Wrong type : Event expected, got #{event.class}" unless event.is_a?(Event)
        raise "Wrong type : date : Numeric expected, got #{date.class}" unless date.is_a?(Numeric)
        add_event_list([[date, event]])
      end

      def pop_next_event
        next_event = nil
        @mutex.synchronize do
          next_event = @event_list.delete_at(0)
        end
        return next_event
      end

      def clear
        @mutex.synchronize do
          @event_list.clear
        end
      end

    end

  end
end
