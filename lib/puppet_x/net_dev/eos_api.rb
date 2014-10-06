# encoding: utf-8

require 'net_http_unix'

##
# PuppetX is where utility extensions live.
module PuppetX
  ##
  # NetDev is the module namespace for puppet supported
  module NetDev
    ##
    # EosApi provides utility methods to interact with the eAPI using JSON-RPC.
    # The API may be accessed over a normal TCP connection using the address
    # and port settings, or a Unix domain socket using a `unix://...` address.
    #
    # @example Get all VLAN identifiers as strings
    #   >> api = EosApi.new(address: 'unix:///var/lib/eapi.sock')
    #   >> vlans = api.all_vlans
    #   >> vlans.keys
    #   => ['1', '3110']
    class EosApi # rubocop:disable Metrics/ClassLength
      # IP address or hostname of the REST api
      attr_reader :address
      # TCP port of the REST api
      attr_reader :port
      # API username
      attr_reader :username
      # API password
      attr_reader :password

      ##
      # initialize an API instance.  The API will communicate with the HTTP
      # server over TCP or a Unix Domain Socket.  If a unix domain socket is
      # being used then the address parameter should be set to the socket path.
      # The port, username, and password are not necessary.
      #
      # @option opts [String] :address The address to connect to the HTTP
      #   server.  This can be a hostname, address or the full path to a unix
      #   domain socket in the form of `unix:///path/to/socket`.
      #
      # @option opts [Fixnum] :port The TCP port for an IP connection to the
      #   HTTP API server.
      #
      # @option opts [String] :username ('admin') The username to log into the
      #   API server when using TCP/IP HTTP API connections.  This option is
      #   not necessary when using a unix:// socket connection.
      #
      # @option opts [String] :password The password to use to log into the API
      #   server.
      #
      # @return [PuppetX::NetDev::EosApi]
      #
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      def initialize(opts = {})
        @address = opts[:address] || ENV['EOS_HOSTNAME'] || 'localhost'
        @port = opts[:port] || ENV['EOS_PORT'] || 80
        @username = opts[:username] || ENV['EOS_USERNAME'] || 'admin'
        @password = opts[:password] || ENV['EOS_PASSWORD'] || 'puppet'
      end

      ##
      # vlan returns data about a specific VLAN identified by the VLAN ID
      # number.  This API call maps roughly to the `show vlan <id>` command.
      # This method returns nil if no VLAN was found matching the ID provided.
      #
      # @param [Fixnum] id The VLAN id to obtain information about.
      #
      # @api public
      #
      # @return [nil,Hash<String,Hash>] Hash describing the VLAN attributes, or
      #   nil if no vlan was found matching the id provided.  The format of
      #   this hash matches the format of {all_vlans}
      def vlan(id)
        result = eapi_action("show vlan #{id}", 'list vlans')
        result.first['vlans'] if result
      end

      ##
      # vlan_create creates a VLAN that does not yet exist on the target
      # device.
      #
      # @param [Fixnum] id The VLAN id to create
      #
      # @api public
      #
      # @return [Boolean] true if the vlan was created
      def vlan_create(id)
        cmds = ['enable', 'configure', "vlan #{id}"]
        eapi_action(cmds, "create vlan #{id}")
      end

      ##
      # vlan_destroy destroys a vlan
      #
      # @param [Integer] id The VLAN ID to destroy
      #
      # @api public
      def vlan_destroy(id)
        cmds = ['enable', 'configure', "no vlan #{id}"]
        eapi_action(cmds, "destroy vlan #{id}")
      end

      ##
      # channel_group_destroy destroys a port channel group.
      #
      # @param [String] name The port channel name, e.g 'Port-Channel3'
      #
      # @api public
      def channel_group_destroy(name)
        # Need to remove all interfaces from the channel group.
        port_channels = all_portchannels_detailed
        channel_group = port_channels[name]
        unless channel_group
          msg = "#{name} is not in #{port_channels.keys.inspect}"
          fail ArgumentError, msg
        end
        interfaces = channel_group['ports']
        interfaces.each { |iface| interface_unset_channel_group(iface) }
      end

      ##
      # interface_unset_channel_group removes a specific interface from all
      # channel groups.
      #
      # @param [String] interface The interface name to remove from its
      #   associated channel group, e.g. 'Ethernet1'
      #
      # @api public
      def interface_unset_channel_group(interface)
        cmds = %w(enable configure) << "interface #{interface}"
        cmds << 'no channel-group'
        eapi_action(cmds, "remove #{interface} from channel group")
      end

      ##
      # interface_set_channel_group configures an interface to be a member of a
      # specified channel group ID.
      #
      # @param [String] interface The interface name to add to the channel
      #   group, e.g. 'Ethernet1'.
      #
      # @option opts [Fixnum] :group The group ID the interface will become a
      #   member of, e.g. 3.
      #
      # @option opts [Symbol] :mode (:active, :passive, :disabled) The LACP
      #   operating mode of the interface.  Note, the only way to change the
      #   LACP mode is to delete the channel group and re-create the channel
      #   group.
      #
      # @api public
      def interface_set_channel_group(interface, opts)
        channel_group = opts[:group]
        mode = case opts[:mode]
               when :active, :passive then opts[:mode]
               when :disabled then :on
               else fail ArgumentError, "Unknown LACP mode #{opts[:mode]}"
               end

        cmd = %w(enable configure) << "interface #{interface}"
        cmd << "channel-group #{channel_group} mode #{mode}"
        msg = "join #{interface} to channel group #{channel_group}"
        eapi_action(cmd, msg)
      end

      ##
      # port_channel_destroy destroys a port channel interface and removes all
      # interfaces from the channel group.
      #
      # @param [String] name The name of the port channel interface, e.g
      #   'Port-Channel3'
      #
      # @api public
      def port_channel_destroy(name)
        cmds = %w(enable configure) << "no interface #{name}"
        eapi_action(cmds, "remove #{name}")
      end

      ##
      # channel_group_create creates a channel group and associated port
      # channel interface if the interface does not already exist.
      #
      # @param [String] name The name of the port channel interface, e.g.
      #   'Port-Channel3'.
      #
      # @option opts [Symbol] :mode (:active, :passive, :disabled) The LACP
      #   operating mode of the interface.  Note, the only way to change the
      #   LACP mode is to delete the channel group and re-create the channel
      #   group.
      #
      # @option opts [Symbol] :interfaces (['Ethernet1', 'Ethernet2']) The
      #   member interfaces of the channel group.
      #
      # @api public
      def channel_group_create(name, opts)
        channel_group = name.scan(/\d+/).first.to_i
        interfaces = [*opts[:interfaces]]
        if interfaces.empty?
          fail ArgumentError, 'Cannot create a channel group with no interfaces'
        end
        interfaces.each do |interface|
          set_opts = { mode: opts[:mode], group: channel_group }
          interface_set_channel_group(interface, set_opts)
        end
      end

      ##
      # set_vlan_name assigns a name to a vlan
      #
      # @param [Integer] id The vlan ID
      #
      # @param [String] name The vlan name
      #
      # @api public
      def set_vlan_name(id, name)
        cmds = ['enable', 'configure', "vlan #{id}"] << "name #{name}"
        eapi_action(cmds, "set vlan #{id} name to #{name}")
      end

      ##
      # set_vlan_state set a vlan to the state specified
      #
      # @param [Integer] id The vlan ID
      #
      # @param [String] state The state of the vlan, e.g. 'active' or
      #   'suspend'
      #
      # @api public
      def set_vlan_state(id, state)
        cmds = ['enable', 'configure', "vlan #{id}"] << "state #{state}"
        eapi_action(cmds, "set vlan #{id} state to #{state}")
      end

      ##
      # all_vlans returns a hash of all vlans
      #
      # @example List all vlans
      #   api.all_vlans
      #   => {
      #   "1"=>{
      #     "status"=>"active",
      #     "name"=>"default",
      #     "interfaces"=>{
      #       "Ethernet2"=>{"privatePromoted"=>false},
      #       "Ethernet3"=>{"privatePromoted"=>false},
      #       "Ethernet1"=>{"privatePromoted"=>false},
      #       "Ethernet4"=>{"privatePromoted"=>false}},
      #     "dynamic"=>false},
      #   "3110"=>{
      #     "status"=>"active",
      #     "name"=>"VLAN3110",
      #     "interfaces"=>{},
      #     "dynamic"=>false}}
      #
      # @api public
      #
      # @return [Hash<String,Hash>]
      def all_vlans
        result = eapi_action('show vlan', 'list all vlans')
        result.first['vlans']
      end

      ##
      # all_portchannels returns a hash of all port channels based on multiple
      # sources of data from the API.
      #
      # @api public
      #
      # @return [Hash<String,Hash>] where the key is the port channel name,
      #   e.g. 'Port-Channel10'
      def all_portchannels
        detailed = all_portchannels_detailed
        modes = all_portchannel_modes
        # Merge the two
        detailed.each_with_object(Hash.new) do |(name, attr), hsh|
          hsh[name] = modes[name] ? attr.merge(modes[name]) : attr
          hsh[name]['minimum_links'] = portchannel_min_links(name)
        end
      end

      ##
      # portchannel_min_links takes the name of a Port Channel interface and
      # obtains the currently configured min-links value by parsing the text of
      # the running configuration.
      #
      # @api private
      #
      # @return [Fixnum] the minimum number of links for the channel group to
      #   become active.
      def portchannel_min_links(name)
        api_commands = ['enable', "show running-config interfaces #{name}"]
        result = eapi_action(api_commands,
                             'obtain port channel min links value',
                             format: 'text')
        text = result[1]['output'] # skip over the enable command output.
        parse_min_links(text)
      end

      ##
      # set_portchannel_min_links Configures the minimum links value for a
      # channel group.
      #
      # @param [String] name The port channel name, e.g 'Port-Channel4'.
      #
      # @param [Fixnum] min_links The minimum number of active links for the
      #   channel group to be active.
      #
      # @api public
      def set_portchannel_min_links(name, min_links)
        cmd = %w(enable configure)
        cmd << "interface #{name}"
        cmd << "port-channel min-links #{min_links}"
        eapi_action(cmd, 'set port-channel min links')
      end

      ##
      # parse_min_links takes the text from the `show running-config interfaces
      # Port-ChannelX` API command and parses out the currently configured
      # number of minimum links.  If there is no min-links value we (safely)
      # assume it is configured to 0.  Example output is:
      #
      #     interface Port-Channel4
      #       description Office Backbone
      #       port-channel min-links 2
      #
      # @param [String] text The raw text output from the API.
      #
      # @api private
      #
      # @return [Fixnum] the number of minimum links
      def parse_min_links(text)
        re = /min-links\s+(\d+)/m
        mdata = re.match(text)
        mdata ? mdata[1].to_i : 0
      end

      ##
      # all_portchannels_detailed returns a hash of all port channels based on
      # the `show etherchannel detailed` command.
      #
      # @api private
      #
      # @return [Hash<String,Hash>] where the key is the port channel name,
      #   e.g. 'Port-Channel10'
      def all_portchannels_detailed
        # JSON format is not supported in EOS 4.13.7M so use text format
        result = eapi_action('show etherchannel detailed', 'list port channels',
                             format: 'text')
        text = result.first['output']
        parse_portchannels(text)
      end

      ##
      # all_portchannel_modes returns a hash of each of the port channel LACP
      # modes.  This method could be merged with the data from the
      # all_portchannels method.
      #
      # @api private
      #
      # @return [Hash<String,Hash>] where the key is the port channel name,
      #   e.g. 'Port-Channel10'
      def all_portchannel_modes
        # JSON format is not supported in EOS 4.13.7M so use text format
        result = eapi_action('show port-channel summary', 'get lag modes',
                             format: 'text')
        text = result.first['output']
        parse_portchannel_modes(text)
      end

      ##
      # Parse the portchannel modes from the text of the `show port-channel
      # summary` command.  The following is an example of two channel groups,
      # one static, one active.
      #
      # rubocop:disable Metrics/LineLength, Metrics/MethodLength, Style/TrailingWhitespace
      #
      #                      Flags
      #     ------------------------ ---------------------------- -------------------------
      #       a - LACP Active          p - LACP Passive           * - static fallback
      #       F - Fallback enabled     f - Fallback configured    ^ - individual fallback
      #       U - In Use               D - Down
      #       + - In-Sync              - - Out-of-Sync            i - incompatible with agg
      #       P - bundled in Po        s - suspended              G - Aggregable
      #       I - Individual           S - ShortTimeout           w - wait for agg
      #     
      #     Number of channels in use: 1
      #     Number of aggregators:1
      #     
      #        Port-Channel       Protocol    Ports
      #     ------------------ -------------- ----------------
      #        Po3(U)             Static       Et1(D) Et2(P)
      #        Po4(D)             LACP(a)      Et3(G-) Et4(G-)
      #
      # @api private
      #
      # @return [Hash<String,Hash>] where the key is the port channel name,
      #   e.g. 'Port-Channel10'
      def parse_portchannel_modes(text)
        lines = text.lines.each_with_object(Array.new) do |v, ary|
          ary << v.chomp if /^\s*Po\d/.match(v)
        end
        lines.each_with_object(Hash.new) do |line, hsh|
          mdata = /^\s+Po(\d+).*?\s+([a-zA-Z()0-9_-]+)/.match(line)
          idx = mdata[1]
          protocol = mdata[2]
          mode = case protocol
                 when 'Static' then :disabled
                 when /LACP/
                   flags = /\((.*?)\)/.match(protocol)[1]
                   if flags.include? 'p' then :passive
                   elsif flags.include? 'a' then :active
                   end
                 end
          hsh["Port-Channel#{idx}"] = { 'mode' => mode }
        end
      end

      ##
      # all_interfaces returns a hash of all interfaces
      #
      # @api public
      #
      # @return [Hash<String,Hash>] where the key is the interface name, e.g.
      #   'Management1'
      def all_interfaces
        result = eapi_action('show interfaces', 'list all interfaces')
        result.first['interfaces']
      end

      ##
      # set_interface_state enables or disables a network interface
      #
      # @param [String] name The interface name, e.g. 'Ethernet1'
      #
      # @param [String] state The interface state, e.g. 'no shutdown' or
      #   'shutdown'
      #
      # @api public
      def set_interface_state(name, state)
        cmd = %w(enable configure) << "interface #{name}" << state
        eapi_action(cmd, "set interface #{name} state to #{state}")
      end

      ##
      # set_interface_description configures the description string for an
      # interface.
      #
      # @param [String] name The interface name, e.g. 'Ethernet1'
      #
      # @param [String] description The description to assign the interface.
      #
      # @api public
      def set_interface_description(name, description)
        cmd = %w(enable configure) << "interface #{name}"
        cmd << "description #{description}"
        eapi_action(cmd, "set interface #{name} description to #{description}")
      end

      ##
      # set_interface_speed enable a network interface
      #
      # @param [String] name The interface name, e.g. 'Ethernet1'
      #
      # @param [String] speed The interface state, e.g. '1000full' or
      #   '40gfull'
      #
      # @api public
      def set_interface_speed(name, speed)
        cmd = %w(enable configure) << "interface #{name}"
        cmd << "speed forced #{speed}"
        eapi_action(cmd, "set interface #{name} speed to #{speed}")
      end

      ##
      # set_interface_mtu configures the interface MTU
      #
      # @param [String] name The interface name, e.g. 'Ethernet1'
      #
      # @param [Fixnum] mtu The interface mtu, e.g. 9000
      #
      # @api public
      def set_interface_mtu(name, mtu)
        cmd = %w(enable configure) << "interface #{name}"
        cmd << "mtu #{mtu}"
        eapi_action(cmd, "set interface #{name} mtu to #{mtu}")
      end

      ##
      # format_error takes the value of the 'error' key from the EOS API
      # response and formats the error strings into a string suitable for error
      # messages.
      #
      # @param [Array<Hash>] data Array of data from the API response, this
      #   will be lcoated in the sub-key api_response['error']['data']
      #
      # @api private
      #
      # @return [String] the human readable error message
      def format_error(data)
        if data
          data.each_with_object([]) do |i, ary|
            ary.push(*i['errors']) if i['errors']
          end.join(', ')
        else
          'unknown error'
        end
      end

      ##
      # http returns a memoized HTTP client instance conforming to the
      # Net::HTTP interface.
      #
      # @api public
      #
      # @return [NetX::HttpUnix]
      def http
        @http ||= NetX::HTTPUnix.new(address, port)
      end

      ##
      # format_command takes an EOS command as a string and returns the
      # appropriate data structure for use with the EOS REST API.
      #
      # @param [String, Array<String>] command The command to execute on the
      #   switch, e.g. 'show vlan' or ['show vlan 1', 'show vlan 2'].
      #
      # @option opts [String] :id The identifier for this request.  If omitted,
      #   a unique identifier will be generated.
      #
      # @option opts [String] :format ('json') The desired format of the
      #   response, e.g. 'text' or 'json'.  Defaults to 'json' if not provided.
      #
      # @api private
      #
      # @return [String] The JSON string suitable for use with HTTP POST API
      #   calls to the EOS API.
      def format_command(command, options = {})
        cmds = [*command]
        req_id = options[:id].nil? ? SecureRandom.uuid : options[:id]
        format = options[:format].nil? ? 'json' : options[:format]
        params = { 'version' => 1, 'cmds' => cmds, 'format' => format }
        request = {
          'jsonrpc' => '2.0', 'method' => 'runCmds',
          'params' => params, 'id' => req_id
        }
        JSON.dump(request)
      end
      private :format_command

      ##
      # parse_portchannels accepts the text output of the `show etherchannel
      # detailed` command and parses the text into structured data with the
      # portchannel names as keys and portchannel attributes as key/values in a
      # hash.
      #
      # @param [String] text The text output to parse.
      #
      # @api private
      #
      # @return [Hash<String,Hash>] where the key is the port channel name,
      #   e.g. 'Port-Channel10'
      def parse_portchannels(text) # rubocop:disable Metrics/MethodLength
        groups = text.split('Port Channel ')
        groups.each_with_object({}) do |str, group|
          lines = [*str.lines]
          name = parse_portchannel_name(lines.shift)
          next unless name
          active_ports = parse_portchannel_active_ports(lines)
          configured_ports = parse_portchannel_configured_ports(lines)
          group[name] = {
            'name'  => name,
            'ports' => [*active_ports, *configured_ports].sort
          }
        end
      end
      private :parse_portchannels

      ##
      # parse_portchannel_active_ports takes a portchannel section from `show
      # port-channel detailed` and parses all of the active ports from the
      # section.
      #
      # @param [Array<String>] lines Array of string lines for the section,
      #
      # @api private
      #
      # @return [Array<String>] Array of string port names, e.g. ['Ethernet1',
      #   'Ethernet2']
      def parse_portchannel_active_ports(group_lines)
        lines = group_lines.dup
        # Check if there are no active ports
        mdata = /(No)? Active Ports/.match(lines.shift)
        return [] if mdata[1] # return if there are none
        lines.shift until /^\s*Port /.match(lines.first) || lines.empty?
        lines.shift(2) # heading line and ---- line
        # Read interfaces until the first blank line
        lines.each_with_object([]) do |l, a|
          l.chomp!
          break a if l.empty?
          a << l.split.first
        end
      end

      ##
      # parse_portchannel_configured_ports takes a portchannel section from
      # `show port-channel detailed` and parses all of the active ports from
      # the section.
      #
      # @param [Array<String>] lines Array of string lines for the section,
      #
      # @api private
      #
      # @return [Array<String>] Array of string port names, e.g. ['Ethernet1',
      #   'Ethernet2']
      def parse_portchannel_configured_ports(group_lines)
        lines = group_lines.dup
        # Check if there are no active ports
        lines.shift until /inactive ports/.match(lines.first) || lines.empty?
        return [] if lines.empty?
        lines.shift(3)
        lines.each_with_object([]) do |l, a|
          l.chomp!
          break a if l.empty?
          a << l.split.first
        end
      end

      ##
      # parse_portchannel_name parses out the portchannel name from the first
      # line of a group section.
      #
      # @param [String] line The first line of a portchannel group detailed
      #   show statement, e.g. 'Port Channel Port-Channel1 (Fallback State:
      #   Unconfigured):'
      #
      # @api private
      #
      # @return [String,nil] the name of the portchannel group or nil if the
      #   name could not be parsed.
      def parse_portchannel_name(line)
        mdata = /^(?:Port Channel )?(Port-Channel\d+)/.match(line)
        mdata[1] if mdata
      end
      private :parse_portchannel_name

      ##
      # eapi_request returns a Net::HTTP::Post instance suitable for use with
      # the http client to make an API call to EOS.  The request will
      # automatically be initialized with an username and password if the
      # attributes have been initialized.
      #
      # @param [String] request_body The data to post to the API represented as
      #   a string, usually JSON encoded.
      #
      # @api private
      #
      # @return [Net::HTTP::Post] A request instance suitable for use with
      #   Net::HTTP#request
      def eapi_request(request_body)
        # JSON-RPC 2.0 to /command-api/ location
        req = Net::HTTP::Post.new('/command-api/')
        req.basic_auth(username, password) if username && password
        req.body = request_body
        req
      end
      private :eapi_request

      ##
      # eapi_call takes a string as an arista command and executes the command
      # on the switch using the eAPI.  This method decodes the API response and
      # returns the value.  For example:
      #
      #     [1] pry(#<PuppetX::NetDev::EosApi>)> eapi_call('show version')
      #     => {"jsonrpc"=>"2.0",
      #      "result"=>
      #       [{"modelName"=>"vEOS",
      #         "internalVersion"=>"4.13.7M-1877079.4137M.1",
      #         "systemMacAddress"=>"00:42:00:08:17:78",
      #         "serialNumber"=>"",
      #         "memTotal"=>2033744,
      #         "bootupTimestamp"=>1403732020.05,
      #         "memFree"=>143688,
      #         "version"=>"4.13.7M",
      #         "architecture"=>"i386",
      #         "internalBuildId"=>"54a9c4ce-bbb0-4f6b-9448-9507de824905",
      #         "hardwareRevision"=>""}],
      #       "id"=>"a4e14732-e0f2-430d-823e-1c801273ec60"}
      #
      # @param [String,Array<String>] command The command or commands to
      #   execute, e.g. 'show vlan'
      #
      # @option opts [String] :id The identifier for this request.  If omitted,
      #   a unique identifier will be generated.
      #
      # @option opts [String] :format ('json') The desired format of the
      #   response, e.g. 'text' or 'json'.  Defaults to 'json' if not provided.
      #
      # @api private
      #
      # @return [Hash] the response from the API
      def eapi_call(command, options = {})
        cmds = [*command]
        request_body = format_command(cmds, options)
        req = eapi_request(request_body)
        resp = http.request(req)
        decoded_response = JSON.parse(resp.body)
        decoded_response
      end
      private :eapi_call

      ##
      # eapi_action makes an API call and handles any error messages in the
      # return value.
      #
      # @param [String,Array<String>] command The command or commands to
      #   execute, e.g. 'show vlan'
      #
      # @param [String] action The action being performed, e.g. 'set interface
      #   description'.  Used to format error messages on API errors.
      #
      # @option opts [String] :id The identifier for this request.  If omitted,
      #   a unique identifier will be generated.
      #
      # @option opts [String] :format ('json') The desired format of the
      #   response, e.g. 'text' or 'json'.  Defaults to 'json' if not provided.
      #
      # @api private
      #
      # @return [Array<Hash>] the value of the 'result' key from the API
      #   response.
      def eapi_action(command, action = 'make api call', options = {})
        api_response = eapi_call(command, options)

        return api_response['result'] unless api_response['error']
        err_msg = format_error(api_response['error']['data'])
        fail Puppet::Error, "could not #{action}: #{err_msg}"
      end
      private :eapi_action

      ##
      # @return [URI] the URI of the server
      def uri
        return @uri if @uri
        if username && password
          @uri = URI("http://#{username}:#{password}@#{address}:#{port}")
        else
          @uri = URI("http://#{address}:#{port}")
        end
      end
    end

    ##
    # EosProviderMethods is meant to be mixed into the provider to make api
    # methods available.
    module EosProviderMethods
      ##
      # api returns a memoized instance of the EosApi.  This method is intended
      # to be used from providers that have mixed in the EosProviderMethods
      # module.
      #
      # @return [PuppetX::NetDev::EosApi] api instance
      def api
        @api ||= PuppetX::NetDev::EosApi.new
      end

      ##
      # bandwidth_to_speed converts a raw bandwidth integer to a Link speed
      # [10m|100m|1g|10g|40g|56g|100g]
      #
      # @param [Fixnum] bandwidth The bandwdith value in bytes per second
      #
      # @api public
      #
      # @return [String] Link speed [10m|100m|1g|10g|40g|56g|100g]
      def bandwidth_to_speed(bandwidth)
        if bandwidth >= 1_000_000_000
          "#{(bandwidth / 1_000_000_000).to_i}g"
        else
          "#{(bandwidth / 1_000_000).to_i}m"
        end
      end

      ##
      # duplex_to_value Convert a duplex string from the API response to the
      # provider value
      #
      # @param [String] duplex The value from the API response
      #
      # @api public
      #
      # @return [Symbol] the value for the provider
      def duplex_to_value(duplex)
        case duplex
        when 'duplexFull' then :full
        when 'duplexHalf' then :half
        else fail ArgumentError, "Unknown duplex value #{duplex.inspect}"
        end
      end

      ##
      # interface_status_to_enable maps the interfaceStatus attribute of the
      # API response to the enable state of :true or :false
      #
      # The interfaceStatus reflects realtime status so its a bit funny how it
      # works.  If interfaceStatus == 'disabled' then the interface is
      # administratively disabled (ie configured to be disabled) otherwise its
      # enabled (ie no shutdown).  So in your conversion here you can just
      # reflect if interfaceStatus == 'disabled' or not as the state.
      #
      # @param [String] status the value of interfaceStatus returned by the API
      #
      # @return [Symbol] :true or :false
      def interface_status_to_enable(status)
        status == 'disabled' ? :false : :true
      end

      ##
      # interface_attributes takes an attribute hash from the EOS API and maps
      # the values to provider attributes for the network_interface type.
      #
      # @param [Hash] attr_hash Interface attribute hash
      #
      # @api public
      #
      # @return [Hash] provider attributes suitable for merge into a provider
      #   hash that will be passed to the provider initializer.
      def interface_attributes(attr_hash)
        hsh = {}
        status = attr_hash['interfaceStatus']
        hsh[:enable]      = interface_status_to_enable(status)
        hsh[:mtu]         = attr_hash['mtu']
        hsh[:speed]       = bandwidth_to_speed(attr_hash['bandwidth'])
        hsh[:duplex]      = duplex_to_value(attr_hash['duplex'])
        hsh[:description] = attr_hash['description']
        hsh
      end

      ##
      # port_channel_attributes takes an attribute hash from the EOS API and
      # maps the values to provider attributes for the port_channel type.
      #
      # @param [Hash] attr_hash Interface attribute hash
      #
      # @api public
      #
      # @return [Hash] provider attributes suitable for merge into a provider
      #   hash that will be passed to the provider initializer.
      def port_channel_attributes(attr_hash)
        hsh = {}
        hsh[:speed]       = bandwidth_to_speed(attr_hash['bandwidth'])
        hsh[:description] = attr_hash['description']
        hsh
      end

      ##
      # flush_speed_and_duplex consolidates the duplex and speed settings into one
      # API call to manage the interface speed.
      #
      # @param [String] name The name of the interface, e.g. 'Ethernet1'
      def flush_speed_and_duplex(name)
        speed = convert_speed(@property_flush[:speed])
        duplex = @property_flush[:duplex]
        return nil unless speed || duplex

        speed_out = speed ? speed : convert_speed(@property_hash[:speed])
        duplex_out = duplex ? duplex.downcase : @property_hash[:duplex].to_s

        api.set_interface_speed(name, "#{speed_out}#{duplex_out}")
      end

      ##
      # convert_speed takes a speed value from the catalog as a string and converts
      # it to a speed prefix suitable for the Arista API.  The following table is
      # used to perform the conversion.
      #
      #   10000full  Disable autoneg and force 10 Gbps/full duplex operation
      #   1000full   Disable autoneg and force 1 Gbps/full duplex operation
      #   1000half   Disable autoneg and force 1 Gbps/half duplex operation
      #   100full    Disable autoneg and force 100 Mbps/full duplex operation
      #   100gfull   Disable autoneg and force 100 Gbps/full duplex operation
      #   100half    Disable autoneg and force 100 Mbps/half duplex operation
      #   10full     Disable autoneg and force 10 Mbps/full duplex operation
      #   10half     Disable autoneg and force 10 Mbps/half duplex operation
      #   40gfull    Disable autoneg and force 40 Gbps/full duplex operation
      #
      # @param [String] speed The speed specified in the catalog, e.g. 1g
      #
      # @api private
      #
      # @return [String] The speed for the API, e.g. 1000
      def convert_speed(value)
        speed = value.to_s
        if /g$/i.match(speed) && (speed.to_i > 40)
          speed
        elsif /g$/i.match(speed)
          (speed.to_i * 1000).to_s
        elsif /m$/i.match(speed)
          speed.to_i.to_s
        end
      end
    end

    ##
    #  EosProviderClassMethods implements common methods, e.g. `self.prefetch`
    #  for EOS providers.
    module EosProviderClassMethods
      ##
      # prefetch associates resources declared in the Puppet catalog with
      # resources discovered on the system using the instances class method.
      # Each resource that has a matching provider in the instances list will
      # have the provider bound to the resource.
      #
      # @param [Hash] resources The set of resources declared in the catalog.
      #
      # @return [Hash<String,Puppet::Type>] catalog resources with updated
      #   provider instances.
      def prefetch(resources)
        provider_hash = instances.each_with_object({}) do |provider, hsh|
          hsh[provider.name] = provider
        end

        resources.each_pair do |name, resource|
          resource.provider = provider_hash[name] if provider_hash[name]
        end
      end
    end
  end
end
