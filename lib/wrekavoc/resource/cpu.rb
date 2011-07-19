require 'wrekavoc'

module Wrekavoc
  module Resource

    class CPU
      class Core
        attr_reader :physicalid,:frequency
        attr_accessor :cache_links
        def initialize(physicalid,freq)
          @physicalid = physicalid
          @frequency = freq
          @cache_links = []
        end
      end

      attr_reader :cores,:critical_cache_links
      def initialize()
        @cores = Hash.new
        @critical_cache_links = []
      end

      def add_core(physicalid,freq)
        raise Lib::AlreadyExistingResourceError if @cores[physicalid]
        @cores[physicalid] = Core.new(physicalid,freq)
      end

      def get_core(physicalid)
        return @cores[physicalid]
      end

      def remove_core(physicalid)
        @cores.delete(physicalid)
      end

      def add_critical_cache_link(cores)
        raise Lib::InvalidParameterError, cores unless cores.is_a?(Array)
        cores.collect! do |core|
          unless core.is_a?(Core)
            core = get_core(core)
            raise Lib::InvalidParameterError, core unless core
          end
          core
        end 

        cores.each do |core|
          core = get_core(core) unless core.is_a?(Core)
          raise raise Lib::InvalidParameterError, core unless core

          tmpcores = cores.dup
          tmpcores.delete(core)
          core.cache_links = tmpcores
        end
        @critical_cache_links << cores
      end
    end

  end
end
