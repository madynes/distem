module Wrekavoc
  module Lib

    class ResourceNotFoundError < Exception
    end

    class InvalidParameterError < Exception
    end

    class UnreachableResourceError < Exception
    end

    class ClientError < Exception
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
