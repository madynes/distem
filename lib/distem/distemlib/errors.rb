module Distem
  module Lib

    class DistemError < Exception # :nodoc:
    end

    # An error related to the resource management
    class ResourceError < DistemError
    end

    # The specified resource was not found
    class ResourceNotFoundError < ResourceError
    end

    # The specified resource is not initialised (and should have been)
    class UninitializedResourceError < ResourceError
    end

    # The specified resource is not reachable
    class UnreachableResourceError < ResourceError
    end

    # The specified resource is not available
    class UnavailableResourceError < ResourceError
    end

    # The specified resource is busy
    class BusyResourceError < ResourceError
    end

    # An error related with the parameters specified to a method
    class ParameterError < DistemError
    end

    # The specified resource already exists
    class AlreadyExistingResourceError < ParameterError
    end

    # A parameter is missing
    class MissingParameterError < ParameterError
    end

    # The specified parameter is not valid
    class InvalidParameterError < ParameterError
    end

    # The specified method is not implemented (yet)
    class NotImplementedError < DistemError
    end

    # The specified probe does not exist
    class InvalidProbeError < DistemError
    end

    # An error occured during the execution of a shell command
    class ShellError < DistemError
      attr_reader :cmd, :ret, :err, :hostname
      def initialize(cmd, ret, err = "")
        @hostname = Socket.gethostname
        @cmd = cmd
        @ret = ret
        @err = err
      end

      def to_s
        return "cmd:'#{@cmd}' host:'#{@hostname}' result:'#{@ret}' err:'#{@err}'"
      end
    end

    # An error occured when using the REST Client (see NetAPI::Client)
    class ClientError < DistemError
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
