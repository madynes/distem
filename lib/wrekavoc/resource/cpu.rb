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
          @frequencies = freqs.sort
          @cache_links = []
        end
      end

      attr_reader :cores,:critical_cache_links,:cores_alloc,:cache_links_size
      def initialize()
        @cores = {}
        @cores_alloc = {}
        @critical_cache_links = []
        @cache_link_size = nil
      end

      def add_core(physicalid,coreid,freq,freqs)
        raise Lib::AlreadyExistingResourceError if @cores[physicalid]
        @cores[physicalid.to_i] = Core.new(physicalid,coreid,freq,freqs)
      end

      def get_core(physicalid)
        return @cores[physicalid.to_i]
      end

      def get_allocated_cores(vnode)
        # Ruby Bug Hash.select should return an Hash
        return @cores_alloc.select{ |core,node| vnode == node }.collect{|v| v[0]}
      end

      def remove_core(physicalid)
        @cores.delete(physicalid.to_i)
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
        @cache_links_size = cores.size unless @cache_links_size
        @critical_cache_links << cores
      end

      def alloc_cores(vnode,corenb=1,cache_linked=false)
        freecores = @cores.values - @cores_alloc.keys
        raise Lib::UnavailableResourceError, "Core x#{corenb}" \
          if freecores.empty? or freecores.size < corenb
        if cache_linked
          corelknb = (corenb.to_f / @cache_links_size).ceil
          realcorenb = corelknb*@cache_links_size
          raise Lib::UnavailableResourceError, "CoreLinked x#{realcorenb}" \
            if freecores.empty? or freecores.size < realcorenb
        
          toallocate = []
          i = 0
          corelknb.times do
            allrelatedfree = false
            curcores = []
            freecores.each do |curcore|
              allrelatedfree = true
              curcores = [curcore]
              curcore.cache_links.each do |core|
                i += 1
                #core = get_core(coreid)
                if allocated_core?(core)
                  allrelatedfree = false
                  break
                end
                curcores << core
              end
              break if allrelatedfree
            end
            if allrelatedfree
              toallocate = toallocate + curcores
              freecores = freecores - curcores
            else
              raise Lib::UnavailableResourceError, "CoreLinked x#{realcorenb} #{i}"
            end
          end
          toallocate.each { |core| @cores_alloc[core] = vnode }
          cores = toallocate
        else
          cores = freecores[0..corenb-1]
        end

        cores.each { |core| @cores_alloc[core] = vnode }

        return cores[0..corenb-1]
      end

      def free_cores(vnode)
        @cores_alloc.delete_if { |core,vnod| vnod == vnode }
      end

      def allocated_core?(core)
        core = get_core(core) if core.is_a?(Numeric)
        raise Lib::InvalidParameterError, core unless core.is_a?(CPU::Core)
        return (@cores_alloc[core] != nil)
      end
    end

  end
end
