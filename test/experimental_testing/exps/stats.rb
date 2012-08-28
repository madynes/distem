require File.join(File.dirname(__FILE__), 'tdata.rb')

class Stats
    def initialize(data = nil)
        @data = data.nil? ? [] : data
    end

    def mean
        sum = @data.reduce :+
        return sum.to_f / @data.length
    end

    def stddev
        m = mean
        dev = @data.map { |x| (x - m)**2 }.reduce(:+) / (@data.length - 1)
        return dev ** 0.5
    end

    def self._confint(pw, m, s, n)
        # t-student confidence interval
        c = Ttable[[ n - 1, pw ]]
        dx = c * s / ( n ** 0.5 )
        return [ m - dx, m + dx ]
    end

    def confint(pw = 0.95)
        return Stats::_confint(pw, mean, stddev, @data.length)
    end

    def error(pw = 0.95)
        return (confint(pw).last - mean)
    end

    def logerror
        # the story goes like that:
        # z = log(x), z + dz = log(x + dx)
        # so:
        # z + dz ~ dx * (log'(x)) + log(x) = (1/Math.log(10)) * dx/x + z
        # dz = (1/Math.log(10)) * dx/x
        return (error / mean) / Math.log(10)
    end

    def logconfint
        return [ mean - logerror, mean + logerror ]
    end

    def push(v)
        @data.push(v)
    end
end
