# encoding: utf-8

module PuppetX
  module NetDev
    class EosApi
      ##
      # SnmpMethods encapsulate the SNMP specific EOS API methods.  This
      # separation makes it easier to provide documentation and introspect
      # where methods come from given an api instance.
      module SnmpMethods
        ##
        # snmp_attributes retrieves the current state of the SNMP service on
        # the device and returns data suitable for a provider instance.
        #
        # @return [Hash<Symbol,String>]
        def snmp_attributes
          rval = { name: 'settings', ensure: :present }
          rval.merge!(snmp_location)
          rval.merge!(snmp_enable)
          rval.merge!(snmp_contact)
        end

        ##
        # snmp_location obtains the configured SNMP location string from
        # the device.
        #
        # @api private
        #
        # @return [Hash<Symbol,String>]
        def snmp_location
          cmd = 'show snmp location'
          result = eapi_action(cmd, 'get snmp location')
          location = result.first['location']
          { location: location }
        end

        ##
        # snmp_enable returns :true if SNMP is enabled on the device or :false
        # otherwise as a Hash suitable for merge into `snmp_attributes`.
        #
        # @api private
        #
        # @return [Hash<Symbol,Symbol>] e.g. `{ enable: :true }`
        def snmp_enable
          cmd = 'show snmp'
          result = eapi_action(cmd, 'get snmp status', format: 'text')
          text = result.first['output']
          enable = parse_snmp_enable(text)
          { enable: enable }
        end

        ##
        # parse_snmp_enable parses the text output of the `show snmp` command
        # an returns :true or :false for the enabled state.
        #
        # @param [String] text The text of the snmp output, e.g. for a disabled
        #   SNMP service:
        #
        #     SNMP agent enabled in VRFs: default
        #     SNMP agent disabled: no communities or users configured
        #
        # @api private
        #
        # @return [Symbol] :true or :false
        def parse_snmp_enable(text)
          disabled_regexp = /SNMP agent disabled:/m
          enabled_regexp = /SNMP packets input/m

          disabled_mdata = disabled_regexp.match(text)
          return :false if disabled_mdata

          enabled_mdata = enabled_regexp.match(text)
          return :true if enabled_mdata

          fail ArgumentError, 'could not parse text for SNMP enabled state'
        end

        ##
        # snmp_contact returns the snmp contact string configured on the device.
        #
        # @api private
        #
        # @return [Hash<Symbol,Symbol>] e.g. `{ contact: 'Jane Doe' }`
        def snmp_contact
          cmd = 'show snmp contact'
          result = eapi_action(cmd, 'get snmp contact')
          contact = result.first['contact']
          { contact: contact }
        end

        ##
        # snmp_enable= disables or enables SNMP
        #
        # @param [Boolean] state enable SNMP if true, disable if false.
        #
        # @api public
        def snmp_enable=(state)
          cmd = %w(enable configure)
          case state
          when true
            cmd << 'snmp-server community public ro'
          when false
            cmd << 'no snmp-server'
          else
            fail ArgumentError, "invalid state #{state.inspect}"
          end

          eapi_action(cmd, 'configure snmp') && true || false
        end

        ##
        # snmp_contact= updates the SNMP contact on the target device.
        #
        # @param [String] contact The contact name, e.g. 'Jane Doe'
        #
        # @api public
        #
        # @return [Boolean] true or false
        def snmp_contact=(contact)
          cmd = %w(enable configure)
          cmd << "snmp-server contact #{contact}"
          eapi_action(cmd, 'set snmp contact') && true || false
        end

        ##
        # snmp_location= updates the SNMP location on the target device.
        #
        # @param [String] location The location, e.g. 'Planet Earth'
        #
        # @api public
        #
        # @return [Boolean] true or false
        def snmp_location=(location)
          cmd = %w(enable configure)
          cmd << "snmp-server location #{location}"
          eapi_action(cmd, 'set snmp location') && true || false
        end

        ##
        # snmp_communities retrieves all of the SNMP community strings defined
        # on the target device and returns an Array of Hash objects suitable
        # for use as a resource hash to the provider's initializer method.
        #
        # @param [String] buf Describe the string parameter here
        #
        # @api public
        #
        # @return [Array<Hash<Symbol,Object>>] Array of resource hashes.
        def snmp_communities
          cmd = 'show snmp community'
          result = eapi_action(cmd, 'get snmp communities', format: 'text')
          text = result.first['output']
          parse_snmp_communities(text)
        end

        ##
        # parse_snmp_communities takes the text output from the `show snmp
        # community` EAPI command and parses the text into structured data
        # suitable for use as a resource hash to the provider initializer
        # method.  An example of the output looks like:
        #
        # ```
        # Community name: jeff
        # Community access: read-write
        # Access list: stest1
        #
        # Community name: jeff2
        # Community access: read-write
        # Access list: stest2 (non-existent)
        #
        # Community name: private
        # Community access: read-write
        #
        # Community name: public
        # Community access: read-only
        # ```
        #
        # @param [String] text The text to parse
        #
        # @api private
        #
        # @return [Array<Hash<Symbol,Object>>] Array of resource hashes.
        def parse_snmp_communities(text)
          blocks = text.split("\n\n")
          # (?:\s*\(.*?\)|\n|$) deals with trailing data after the value.  e.g.
          # an ACL might come back as `Access list: stest2 (non-existent)`
          regexp = / (\w+): (\w.*?)(?:\s*\(.*?\)|\n|$)/
          communities = blocks.map { |l| l.scan(regexp) }
          communities.map do |pairs|
            pairs.each_with_object({}) do |(key, val), resource_hash|
              resource_hash.merge!(map_snmp_keys(key, val))
            end
          end
        end

        ##
        # map_snmp_keys maps the keys and values parsed from the show snmp
        # community raw text output into resource attributes and values.
        #
        # @api private
        def map_snmp_keys(key, val)
          case key
          when 'name' then { name: val }
          when 'list' then { acl: val }
          when 'access'
            group = case val
                    when 'read-write'; then 'rw'
                    when 'read-only'; then 'ro'
                    end
            { group: group }
          end
        end
        private :map_snmp_keys
      end
    end
  end
end
