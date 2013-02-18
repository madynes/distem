
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

        event = nil
        date = 0

        runblock = Proc.new {
          init_time = Time.now

          begin
            event.trigger(@event_trace, date) if event
            date, event = @event_trace.pop_next_event
            if date
              sleep_time = init_time + date - Time.now
              sleep sleep_time if sleep_time > 0
            end
          end while event
        }

        @running_thread = Thread.new {
          runblock.call
        }

      end

      def stop
        @running_thread.exit if @running_thread
        @running_thread = nil
        @event_trace.clear
      end
    end
  end
end
