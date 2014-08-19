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
    class EosApi # rubocop:disable Style/ClassLength
      attr_reader :address, :port, :username, :password

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
      def initialize(opts = {})
        @address = opts[:address]
        @port = opts[:port]
        @username = opts[:username] || 'admin'
        @password = opts[:password]
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
      # all_interfaces returns a hash of all interfaces
      #
      # @api public
      #
      # @return [Hash<String,Hash>]
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
      # @param [String] id The identifier for this request.  If omitted, a
      #   unique identifier will be generated.
      #
      # @api private
      #
      # @return [String] The JSON string suitable for use with HTTP POST API
      #   calls to the EOS API.
      def format_command(command, id = nil)
        cmds = [*command]
        req_id = id.nil? ? SecureRandom.uuid : id
        params = { 'version' => 1, 'cmds' => cmds, 'format' => 'json' }
        request = {
          'jsonrpc' => '2.0', 'method' => 'runCmds',
          'params' => params, 'id' => req_id
        }
        JSON.dump(request)
      end
      private :format_command

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
      # @api private
      #
      # @return [Hash] the response from the API
      def eapi_call(command)
        cmds = [*command]
        request_body = format_command(cmds)
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
      # @api private
      #
      # @return [Array<Hash>] the value of the 'result' key from the API
      #   response.
      def eapi_action(command, action = 'make api call')
        api_response = eapi_call(command)

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
        ## FIXME remove the hard coded address and make this configurable.
        @api ||= PuppetX::NetDev::EosApi.new(
          address: 'dhcp150.jeff.backline.puppetlabs.net',
          port: 80,
          username: 'admin',
          password: 'puppet')
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
        else fail ArgumentError, "Unknown duplex value #{duplex}"
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
        if status == 'disabled' then :false else :true end
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
    end
  end
end
