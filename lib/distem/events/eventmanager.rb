require 'distem'

module Distem
  module Events

    class EventManager

      # Event trace
      attr_reader :event_trace

      def initialize(trace = nil)
        @event_trace = trace
        @running_thread = nil
      end

      def set_trace(trace)
        @running_thread.exit if @running_thread
        @event_trace = trace
      end

      def run

        raise "No event trace is set" unless @event_trace
        raise "The event manager is already started!" if (@running_thread and @running_thread.alive?)

        next_event = nil

        runblock = Proc.new {
          init_time = Time.now

          begin
            next_event.trigger(@event_trace) if next_event
            next_date, next_event = @event_trace.pop_next_event
            if next_date and next_date > 0
              sleep_time = init_time + next_date - Time.now
              sleep sleep_time
            end
          end while next_event
        }
        
        @running_thread = Thread.new {
          runblock.call
        }
        
      end

      def stop
        set_trace(nil)
      end
    end
  end
end
