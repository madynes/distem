require 'wrekavoc'

module Wrekavoc
  module Resource

    class CPU
      class Core
        attr_reader :physicalid,:coreid,:frequency,:frequencies
        attr_accessor :cache_links
        def initialize(physicalid,coreid,freq,freqs)
          @physicalid = physicalid
          @coreid = coreid
          @frequency = freq
          @frequencies = freqs
          @cache_links = []
        end
      end

      attr_reader :cores,:critical_cache_links,:cores_alloc
      def initialize()
        @cores = {}
        @cores_alloc = {}
        @critical_cache_links = []
      end

      def add_core(physicalid,coreid,freq,freqs)
        raise Lib::AlreadyExistingResourceError if @cores[physicalid]
        @cores[physicalid] = Core.new(physicalid,coreid,freq,freqs)
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

      def alloc_cores(vnode,corenb=1)
        freecores = @cores.values - @cores_alloc.keys
        raise Lib::UnavailableResourceError, "Core x#{corenb}" \
          if freecores.empty? or freecores.size < corenb
        cores = freecores[0..corenb-1]
        cores.each { |core| @cores_alloc[core] = vnode }
        return cores
      end

      def free_cores(vnode)
        @cores_alloc.delete_if { |core,vnod| vnod == vnode }
      end
    end

  end
end
