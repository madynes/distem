require 'wrekavoc'
require 'ext/cpuhogs'

module Wrekavoc
  module Limitation
    module CPU

      class HogsAlgorithm
        def initialize()
          @pid = nil
        end

        def apply(vcpu)
          coresdesc = []
          vcpu.vcores.each_value do |vcore|
            coresdesc << "#{vcore.pcore.physicalid}:#{vcore.frequency*1024} " \
              if vcore.frequency < vcore.pcore.frequency
          end

          unless coresdesc.empty?
            @pid = fork { 
              c = CPUExtension::CPUHogs.new
              c.run(coresdesc)
            }
            begin
              Process.kill(0,@pid)
            rescue Errno::ESRCH
              raise Lib::ShellError.new('CPUHogs','Command failed')
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
