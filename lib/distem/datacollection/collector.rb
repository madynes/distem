require 'thread'

module Distem
  module DataCollection
    class Collector
      @probes = nil
      attr_reader :data

      def initialize(ref_time, desc)
        @probes = []
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
          @probes << klass.new(drift, @data[params['name']], params)
        }
      end

      def run
        @probes.each { |i| i.run }
      end

      def stop
        @probes.each { |i| i.stop }
      end

      def restart
        @probes.each { |i| i.restart }
      end
    end
  end
end
