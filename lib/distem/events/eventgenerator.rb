
module Distem
  module Events

    # Class to generate events from a probabilist distribution
    class EventGenerator < Event

      def initialize(resource_desc, change_type, generator_desc, event_value = nil, random_generators = nil)

        @generator_desc = generator_desc
        @random_generators = {}
        @random_generators = random_generators if random_generators

        if change_type == 'churn'
          event_value = 'down' unless event_value

          if @generator_desc['date']
            if @generator_desc['availability'] or @generator_desc['unavailability']
              raise "You cannot give a date generator and an availability or unavailability generator"
            end

            # same distribution for avaibility and unavailability time
            @generator_desc['availability'] = @generator_desc['date']
            @generator_desc['unavailability'] = @generator_desc['date']
            @generator_desc['date'] = nil
          else
            unless @generator_desc['availability'] and @generator_desc['unavailability']
              raise "You must give availability and unavailability generators"
            end
          end

          @random_generators['availability'] = RngStreamRandomGenerator.new unless @random_generators['availability']
          @random_generators['unavailability'] = RngStreamRandomGenerator.new unless @random_generators['unavailability']

        else
          raise "No description given for the date generator" unless @generator_desc['date']
          raise "No description given for the value generator" unless @generator_desc['value']

          @random_generators['value'] = RngStreamRandomGenerator.new unless @random_generators['value']

          event_value = get_random_value('value')
          if change_type == 'power'
            # For this event,  non-integer values are accepted only if between 0 and 1
            event_value = event_value.round if event_value > 1
          else
            #No integer value allowed - As 0 means infinity in some cases, we only start from 1
            event_value = event_value.round
            event_value = 1 if event_value == 0
          end
        end

        super(resource_desc, change_type, event_value)

        @random_generators['date'] = RngStreamRandomGenerator.new unless @random_generators['date']

      end

      def get_next_date
        if @change_type == 'churn'
          if @event_value == 'down'
            # The resource will be down on the next trigger; for the moment, it should be up.
            # So we use the availability distribution to compute the next date
            return get_random_value('availability')
          else
            return get_random_value('unavailability')
          end
        else
          return get_random_value('date')
        end
      end

      def trigger(event_list, date)
        super
        generated_date = get_next_date
        if generated_date
          next_event = get_next_event
          next_date = generated_date + date
          event_list.add_event(next_date, next_event)
        end
      end

      protected

      def get_next_event
        next_value = nil
        if @change_type == 'churn'
          next_value = (@event_value == 'up' ? 'down' : 'up')
        end
        return EventGenerator.new(@resource_desc, @change_type, @generator_desc, next_value, @random_generators)
      end

      # Get a value for the choosen generator, 'date' or 'value'
      def get_random_value(generator)
        generator_parameters = @generator_desc[generator]
        random_generator = @random_generators[generator]

        if generator_parameters['distribution'] == 'uniform'
          return generator_parameters['min'].to_f +
              (generator_parameters['max'].to_f - generator_parameters['min'].to_f) * random_generator.rand_U01

        elsif generator_parameters['distribution'] == 'exponential'
          return -Math::log(random_generator.rand_U01) / generator_parameters['rate'].to_f

        elsif generator_parameters['distribution'] == 'weibull'
          return generator_parameters['scale'] * ( (-Math::log(random_generator.rand_U01)) ** (1.0 / generator_parameters['shape'].to_f) )

        elsif generator_parameters['distribution'] == 'always'
          # This case could be used for churn, when one wants a resource
          # to be up or down forever after the previous trigger.
          # Thus, no event will be set, so we return a nil date
          return nil

        else
          raise "Probabilist distribution not supported : #{generator_parameters['distribution']}"
        end
      end

    end

  end
end
