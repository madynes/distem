require 'wrekavoc'

module Wrekavoc
  module Lib

    class Validator
      DEFAULT_WREKAVOC = {
        'vplatform' => {
          'pnodes' => {
            'id' => nil,
            'address' => nil,
            'status' => nil,
          },
          'vnodes' => {
            'id' => nil,
            'name' => nil,
            'host' => nil,
            'filesystem' => {
              'vnode' => 'nil',
              'image' => 'nil',
              'path' => 'nil',
            },
            'gateway' => nil,
            'vifaces' => {
              'id' => nil,
              'name' => nil,
              'vnode' => nil,
              'address' => nil,
              'vnetwork' => nil,
              'limit_output' => {
                'vnode' => nil,
                'viface' => nil,
                'direction' => nil,
                'properties' => {
                  'type' => nil
                },
              },
              'limit_input' => {
                'vnode' => nil,
                'viface' => nil,
                'direction' => nil,
                'properties' => {
                  'type' => nil
                },
              },
            },
            'status' => nil,
          },
          'vnetworks' => {
            'name' => nil,
            'address' => nil,
            'vroutes' => {
              'id' => nil,
              'srcnet' => nil,
              'dstnet' => nil,
              'gw' => nil,
            }
          }
        }
      }

      def self.validate(object)
        return true
      end

      def self.validate_hash(hash,expected=DEFAULT_WREKAVOC)
        valid = expected.keys.size == hash.keys.size
        return false unless valid

        array = []
        key = ''
        block = Proc.new {
          array.each do |val|
            valid = valid and validate_hash(val,expected[key])
            break unless valid
          end
        }
        expected.keys.all? do |key|
          if hash.has_key?(key)
            if key[-1..-1] == 's' and hash[key]
              if hash[key].is_a?(Hash)
                array = hash[key].values
                block.call
              elsif hash[key].is_a?(Array)
                array = hash[key]
                block.call
              end
            else
              if hash[key].is_a?(Hash)
                validate_hash(hash[key],expected[key])
              end
            end
          else
            valid = false
          end
          break unless valid
        end
      end
    end

  end
end
