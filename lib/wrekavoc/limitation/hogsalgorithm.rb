module Wrekavoc
  module Limitation
    module CPU

      class HogsAlgorithm
        PATH_CURRENT=File.expand_path(File.dirname(__FILE__))
        PATH_UTILS_BIN=File.expand_path('../../utils/bin/',PATH_CURRENT)
        CPUHOGS_BIN=File.join(PATH_UTILS_BIN,'cpuhogs')

        def initialize()
          raise Lib::ShellError.new(CPUHOGS_BIN,'not found') \
            unless File.exists?(CPUHOGS_BIN)
          @pid = nil
        end

        def apply(vcpu)
          raise Lib::ShellError.new(CPUHOGS_BIN,'command not found') \
            unless File.exists?(CPUHOGS_BIN)

          coresdesc = ""
          vcpu.vcores.each_value do |vcore|
            coresdesc += "#{vcore.pcore.physicalid}:#{vcore.frequency*1024} " \
              if vcore.frequency < vcore.pcore.frequency
          end

          unless coresdesc.empty?
            @pid = fork { exec("#{CPUHOGS_BIN} #{coresdesc}") }
            begin
              Process.kill(0,@pid)
            rescue Errno::ESRCH
              raise Lib::ShellError.new(CPUHOGS_BIN,'Command failed')
            end
          end
        end

        def undo()
          Process.kill('SIGTERM',@pid) if @pid
          @pid = nil
        end
      end

    end
  end
end
