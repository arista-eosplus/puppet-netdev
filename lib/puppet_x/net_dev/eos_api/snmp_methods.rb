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
      end
    end
  end
end
