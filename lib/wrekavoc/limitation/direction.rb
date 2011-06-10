module Wrekavoc
  module Limitation
    module Network

      class Direction
        INPUT = 0
        OUTPUT = 1

        def self.to_string(dir)
          ret = ""
          case dir
            when INPUT
              ret = "INPUT"
            when OUTPUT
              ret = "OUTPUT"
            else
              ret = "UNKNOWN"
          end
          return ret
        end
      end

    end
  end
end
