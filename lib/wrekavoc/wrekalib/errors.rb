module Wrekavoc
  module Lib

    class WrekavocError < Exception
    end

    class ResourceError < WrekavocError
    end

    class ResourceNotFoundError < ResourceError
    end

    class UninitializedResourceError < ResourceError
    end

    class UnreachableResourceError < ResourceError
    end

    class UnavailableResourceError < ResourceError
    end

    class ParameterError < WrekavocError
    end

    class AlreadyExistingResourceError < ParameterError
    end

    class MissingParameterError < ParameterError
    end

    class InvalidParameterError < ParameterError
    end

    class NotImplementedError < WrekavocError
    end

    class ShellError < WrekavocError
      attr_reader :cmd, :ret, :hostname
      def initialize(cmd, ret)
        @hostname = Socket.gethostname
        @cmd = cmd
        @ret = ret
      end

      def to_s
        return "cmd:'#{@cmd}' host:'#{@hostname}' result:'#{@ret}'"
      end
    end

    class ClientError < WrekavocError
      attr_reader :num, :desc, :body
      def initialize(num = 0, desc = "", body = {})
        @num = num
        @desc = desc
        @body = body
      end

      def to_s
        if body.is_a?(Hash) or body.is_a?(Array)
          body = @body.inspect 
        else
          body = @body
        end

        return "HTTP Status: #{@num},\nDescription: \"#{@desc}\",\nBody: #{body}\n"
      end
    end

  end
end
