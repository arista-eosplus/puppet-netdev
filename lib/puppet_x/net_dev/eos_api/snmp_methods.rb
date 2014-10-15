# encoding: utf-8

module PuppetX
  module NetDev
    ##
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

        ##
        # snmp_community_set creates or updates an snmp community on the target
        # device given a hash of attributes from the resource model.
        #
        # @option opts [String] :name ('public') The community name
        #
        # @option opts [Symbol] :group (:ro) :ro or :rw for read-only or
        #   read-write access control for the community name.
        #
        # @option opts [String] :acl ('stest1') The standard ACL name defined on
        #   the switch.  This ACL is defined using the `ip access-list standard
        #   stest1` command.
        #
        # @api public
        #
        # @return [Boolean] true if the resource was successfully created
        def snmp_community_set(opts)
          prefix = %w(enable configure)
          cmd = "snmp-server community #{opts[:name]}"
          cmd << " #{opts[:group]}" if opts[:group]
          cmd << " #{opts[:acl]}" if opts[:acl]
          eapi_action([*prefix, cmd], 'define snmp community') && true || false
        end

        ##
        # snmp_community_destroy deletes an SNMP community from the target
        # device.  given a hash of attributes from the resource model.
        #
        # @option opts [String] :name ('public') The community name
        #
        # @api public
        #
        # @return [Boolean] true if the resource was successfully created
        def snmp_community_destroy(opts)
          prefix = %w(enable configure)
          cmd = "no snmp-server community #{opts[:name]}"
          result = eapi_action([*prefix, cmd], 'destroy snmp community')
          result && true || false
        end

        ##
        # snmp_notifications returns an Array of resource hashes suitable for
        # initializing new provider resources.
        #
        # @api public
        #
        # @return [Array<Hash<Symbol,Object>>] Array of resource hashes.
        def snmp_notifications
          cmd = 'show snmp trap'
          result = eapi_action(cmd, 'get snmp traps', format: 'text')
          text = result.first['output']
          parse_snmp_traps(text)
        end

        ##
        # parse_snmp_traps takes the raw text output of the `show snmp trap`
        # command and parses the data into hases suitable for new provider
        # instances.
        #
        # @param [String] text The raw text to process.
        #
        # @api private
        #
        # @return [Array<Hash<Symbol,Object>>] Array of resource hashes.
        def parse_snmp_traps(text)
          regexp = /(\w+)\s+([-_\w]+)\s+(\w+).*$/
          triples = text.scan(regexp)
          triples.shift # Header
          triples.map do |triple|
            {
              name: format('%s %s', *triple),
              enable: /yes/xi.match(triple[2]) ? :true : :false
            }
          end
        end

        ##
        # snmp_notification_set configures a SNMP trap notification on the
        # target device.
        #
        # @option opts [String] :name ('snmp link-down') The trap name with the
        #   type name as a prefix separated by a space.  The special name 'all'
        #   will enable or disable all notifications.
        #
        # @option opts [Symbol] :enable (:true) :true to enable the
        #   notification, :false to disable the notification.
        #
        # @api public
        #
        # @return [Boolean] true if successful
        def snmp_notification_set(opts)
          prefix = %w(enable configure)
          pre = opts[:enable] == :true ? '' : 'no '
          suffix = opts[:name] == 'all' ? '' : " #{opts[:name]}"
          cmd = pre << 'snmp-server enable traps' << suffix
          result = eapi_action([*prefix, cmd], 'set snmp trap')
          result && true || false
        end

        ##
        # snmp_notification_receivers obtains a list of all the snmp
        # notification receivers and returns them as an Array of resource
        # hashes suitable for the provider's new class method.  This command
        # maps the `show snmp host` command to an array of resource hashes.
        #
        # @api public
        #
        # @return [Array<Hash<Symbol,Object>>] Array of resource hashes.
        def snmp_notification_receivers
          cmd = 'show snmp host'
          msg = 'get snmp notification hosts'
          result = eapi_action(cmd, msg, format: 'text')
          text = result.first['output']
          parse_snmp_hosts(text)
        end

        ##
        # parse_snmp_hosts parses the raw text from the `show snmp host`
        # command and returns an Array of resource hashes.
        #
        # rubocop:disable Metrics/MethodLength
        #
        # @param [String] text The text of the `show snmp host` output, e.g.
        #   for three hosts:
        #
        #   ```
        #   Notification host: 127.0.0.1       udp-port: 162   type: trap
        #   user: public                       security model: v3 noauth
        #
        #   Notification host: 127.0.0.1       udp-port: 162   type: trap
        #   user: smtpuser                     security model: v3 auth
        #
        #   Notification host: 127.0.0.2       udp-port: 162   type: trap
        #   user: private                      security model: v2c
        #
        #   Notification host: 127.0.0.3       udp-port: 162   type: trap
        #   user: public                       security model: v1
        #
        #   Notification host: 127.0.0.4       udp-port: 10162 type: inform
        #   user: private                      security model: v2c
        #
        #   Notification host: 127.0.0.4       udp-port: 162   type: trap
        #   user: priv@te                      security model: v1
        #
        #   Notification host: 127.0.0.4       udp-port: 162   type: trap
        #   user: public                       security model: v1
        #
        #   Notification host: 127.0.0.4       udp-port: 20162 type: trap
        #   user: private                      security model: v1
        #
        #   ```
        #
        # @api private
        #
        # @return [Array<Hash<Symbol,Object>>] Array of resource hashes.
        def parse_snmp_hosts(text)
          re = /host: ([^\s]+)\s+.*?port: (\d+)\s+type: (\w+)\s*user: (.*?)\s+security model: (.*?)\n/m # rubocop:disable Metrics/LineLength
          text.scan(re).map do |(host, port, type, username, auth)|
            resource_hash = { name: host, ensure: :present, port: port.to_i }
            sec_match = /^v3 (\w+)/.match(auth)
            resource_hash[:security] = sec_match[1] if sec_match
            ver_match = /^(v\d)/.match(auth) # first 2 characters
            resource_hash[:version] = ver_match[1] if ver_match
            resource_hash[:type] = /trap/.match(type) ? :traps : :informs
            resource_hash[:username] = username if /^v3/.match(auth)
            resource_hash[:community] = username unless /^v3/.match(auth)
            resource_hash
          end
        end

        ##
        # snmp_notification_receiver_set takes a resource hash and configures a
        # SNMP notification host on the target device.  In practice this method
        # usually creates a resource because nearly all of the properties can
        # vary and are components of a resource identifier.
        #
        # @option opts [String] :name ('127.0.0.1') The hostname or ip address
        #   of the snmp notification receiver host.
        #
        # @option opts [String] :username ('public') The SNMP username, or
        #   community, to use for authentication.
        #
        # @option opts [Fixnum] :port (162) The UDP port of the receiver.
        #
        # @option opts [Symbol] :version (:v3) The version, :v1, :v2, or :v3
        #
        # @option opts [Symbol] :type (:traps) The notification type, :traps or
        #   :informs.
        #
        # @option opts [Symbol] :security (:auth) The security mode, :auth,
        #   :noauth, or :priv
        #
        # @api public
        #
        # @return [Boolean]
        def snmp_notification_receiver_set(opts = {})
          prefix = %w(enable configure)
          cmd = snmp_notification_receiver_cmd(opts)
          result = eapi_action([*prefix, cmd], 'set snmp host')
          result ? true : false
        end

        ##
        # snmp_notification_receiver_cmd builds a command given a resource
        # hash.
        #
        # @return [String]
        def snmp_notification_receiver_cmd(opts = {})
          host = opts[:name].split(':').first
          version = /\d+/.match(opts[:version]).to_s
          version.sub!('2', '2c')
          cmd = "snmp-server host #{host}"
          cmd << " #{opts[:type] || :traps}"
          cmd << " version #{version}"
          cmd << " #{opts[:security] || :noauth}" if version == '3'
          cmd << " #{opts[:username] || opts[:community]}"
          cmd << " udp-port #{opts[:port]}"
          cmd
        end
        private :snmp_notification_receiver_cmd

        ##
        # snmp_notification_receiver_remove removes an snmp-server host from
        # the target device.
        #
        # @option opts [String] :name ('127.0.0.1') The hostname or ip address
        #   of the snmp notification receiver host.
        #
        # @option opts [String] :username ('public') The SNMP username, or
        #   community, to use for authentication.
        #
        # @option opts [Fixnum] :port (162) The UDP port of the receiver.
        #
        # @option opts [Symbol] :version (:v3) The version, :v1, :v2, or :v3
        #
        # @option opts [Symbol] :type (:traps) The notification type, :traps or
        #   :informs.
        #
        # @option opts [Symbol] :security (:auth) The security mode, :auth,
        #   :noauth, or :priv
        #
        # @api public
        #
        # @return [Boolean]
        def snmp_notification_receiver_remove(opts = {})
          prefix = %w(enable configure)
          cmd = 'no ' << snmp_notification_receiver_cmd(opts)
          result = eapi_action([*prefix, cmd], 'remove snmp host')
          result ? true : false
        end
      end
    end
  end
end
