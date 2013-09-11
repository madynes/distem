require 'thread'

module Distem
  module DataCollection
    class Collector
      @indicators = nil
      attr_reader :data

      def initialize(ref_time, desc)
        @indicators = []
        @data = {}
        drift = ref_time - Time.now.to_f
        desc.each_pair { |k,params|
          klass = nil
          begin
            klass = DataCollection.const_get(k)
            raise if (klass.superclass != DataCollection::Probe)
          rescue
            raise Lib::InvalidProbeError, k
          end
          raise Lib::ParameterError unless (params.has_key?('frequency') && (params['frequency'].is_a?(Float) || params['frequency'].is_a?(Fixnum)))
          raise Lib::ParameterError unless (params.has_key?('name') && params['name'].is_a?(String))
          @data[params['name']] = []
          @indicators << klass.new(drift, @data[params['name']], params)
        }
      end

      def run
        @indicators.each { |i| i.run }
      end

      def stop
        @indicators.each { |i| i.stop }
      end
    end
  end
end
