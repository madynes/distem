
module Distem
  module Resource

    # Abstract representation of a physical CPU resource
    class CPU
      # Abstract representation of a physical Core resource
      class Core
        # The physical (unique) id of the Core (cgroups, cpufreq, field processor in /proc/cpuinfo)
        attr_reader :physicalid
        # The logical id of the Core (used by some softwares)
        attr_reader :coreid
        # The actually set frequency (KHz)
        attr_reader :frequency
        # Available frequencies of that core (CPU throttling)
        attr_reader :frequencies
        # Cores which have a critical cache link with this one
        attr_accessor :cache_links

        # Create a new Core
        # ==== Attributes
        # * +physicalid+ The physical (unique) id of the Core (cgroups, cpufreq, field processor in /proc/cpuinfo)
        # * +coreid+ The logical id of the Core (used by some softwares)
        # * +freq+ The actually set (KHz)
        # * +freqs+ Available frequencies of that core (CPU throttling)
        #
        def initialize(physicalid,coreid,freq,freqs)
          @physicalid = physicalid
          @coreid = coreid
          @frequency = freq
          @frequencies = freqs.sort
          @cache_links = []
        end
      end

      # The CPU cores list
      attr_reader :cores
      # The CPU cores allocation list (each core can be allocated to a VNode)
      attr_reader :cores_alloc
      # Cores critical cache links list 
      attr_reader :critical_cache_links
      # The size of a cached linked core "group"
      attr_reader :cache_links_size

      # Create a new CPU
      def initialize()
        @cores = {}
        @cores_alloc = {}
        @critical_cache_links = []
        @cache_links_size = nil
      end

      # Add a new Core to the CPU
      # ==== Attributes
      # * +physicalid+ The physical (unique) id of the Core (cgroups, cpufreq, field processor in /proc/cpuinfo)
      # * +coreid+ The logical id of the Core (used by some softwares)
      # * +freq+ The actually set (KHz)
      # * +freqs+ Available frequencies of that core (CPU throttling)
      #
      def add_core(physicalid,coreid,freq,freqs)
        raise Lib::AlreadyExistingResourceError if @cores[physicalid]
        @cores[physicalid.to_i] = Core.new(physicalid,coreid,freq,freqs)
      end

      # Get the specified Core
      # ==== Attributes
      # * +physicalid+ The physicalid of the core to be returned
      # ==== Returns
      # Core object
      #
      def get_core(physicalid)
        return @cores[physicalid.to_i]
      end

      # Get cores that are associated with a VNode
      # ==== Attributes
      # * +vnode+ The VNode object
      # ==== Returns
      # Array of Core objects
      #
      def get_allocated_cores(vnode)
        # Ruby Bug Hash.select should return an Hash
        return @cores_alloc.select{ |core,node| vnode == node }.collect{|v| v[0]}
      end

      # Get cores that are not associated with any VNode at the moment
      # ==== Returns
      # Array of Core objects
      #
      def get_free_cores
        return @cores.values - @cores_alloc.keys
      end

      # Dettach a Core from this CPU
      # ==== Attributes
      # * +physicalid+ The physical id of the Core to dettach
      #
      def remove_core(physicalid)
        @cores.delete(physicalid.to_i)
      end

      # Add a critical cache link between several cores (critical because e.g. that cores have to change their frequency together)
      # ==== Attributes
      # * +cores+ The Array containing the Cores to be linked
      #
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

      # Allocate Cores to a VNode
      # ==== Attributes
      # * +vnode+ The VNode object
      # * +corenb+ The number of Cores to allocate
      # * +cache_linked+ Specify if the allocated Cores should be or not cache linked
      # ==== Exceptions
      # * +UnavailableResourceError+ If there is no more cores available (or if there it's not possible to find +corenb+ cache linked Cores to allocate)
      #
      def alloc_cores(vnode,corenb=1,cache_linked=false)
        freecores = get_free_cores
        raise Lib::UnavailableResourceError, "Core x#{corenb}" \
          if freecores.empty? or freecores.size < corenb
        if cache_linked
          clsize = (@cache_links_size ? @cache_links_size : 1)
          corelknb = (corenb.to_f / clsize).ceil
          realcorenb = corelknb*clsize
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

      # "Desallocate" the Cores that was associated to a VNode
      # ==== Attributes
      # * +vnode+ The VNode object
      #
      def free_cores(vnode)
        @cores_alloc.delete_if { |core,vnod| vnod == vnode }
      end

      # Check if a specified Core is already allocated to a VNode
      # ==== Attributes
      # * +vnode+ The Core object
      # ==== Returns
      # Boolean value
      #
      def allocated_core?(core)
        core = get_core(core) if core.is_a?(Numeric)
        raise Lib::InvalidParameterError, core unless core.is_a?(CPU::Core)
        return (@cores_alloc[core] != nil)
      end
    end

  end
end
