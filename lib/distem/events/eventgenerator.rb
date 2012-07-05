require 'distem'

module Distem
  module Events

    # Class to generate events from a probabilist distribution
    class EventGenerator < Event

      def initialize(resource_desc, change_type, generator_desc, event_value = nil)

        if change_type == 'churn'
          event_value = 'down' unless event_value
        else
          raise "No description given for the value generator" unless generator_desc['value']
          @value_generator = SimpleRandomGenerator.new
          @value_generator_params = generator_desc['value']
          event_value = get_random_value(@value_generator, @value_generator_params)
        end

        super(resource_desc, change_type, event_value)

        raise "No description given for the date generator" unless generator_desc['date']
        @date_generator = SimpleRandomGenerator.new
        @date_generator_params = generator_desc['date']

      end

      def get_next_date
        # TODO generate a new date for the next event
      end

      def trigger(event_list)
        super
        next_event = get_next_event
        next_date = get_next_date
        event_list.add_event(next_date, next_event)
      end

      protected

      def get_next_event
        # TODO create a new EventGenerator, with a new value
      end

      def get_random_value(random_generator, generator_parameters)
        # TODO generate a new random value, given the generator parameters
      end

    end

  end
end
