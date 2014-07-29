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
    class EosApi
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
        api_response = eapi_call("show vlan #{id}")
        result = api_response['result']
        if result
          return result.first['vlans']
        else
          return nil
        end
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
        api_response = eapi_call(cmds)

        err = api_response['error']
        return true unless err
        fail Puppet::Error, "could not create vlan #{id}: #{JSON.dump(err)}"
      end

      ##
      # vlan_destroy destroys a vlan
      #
      # @param [Integer] id The VLAN ID to destroy
      #
      # @api public
      def vlan_destroy(id)
        cmds = ['enable', 'configure', "no vlan #{id}"]
        api_response = eapi_call(cmds)

        err = api_response['error']
        return nil unless err
        fail Puppet::Error, "could not create vlan #{id}: #{JSON.dump(err)}"
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
        cmds = ['enable', 'configure', "vlan #{id}"]
        cmds << "name #{name}"
        api_response = eapi_call(cmds)

        err = api_response['error']
        return nil unless err
        msg = "could not name vlan #{id} as #{name}: #{JSON.dump(err)}"
        fail Puppet::Error, msg
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
        cmds = ['enable', 'configure', "vlan #{id}"]
        cmds << "state #{state}"
        api_response = eapi_call(cmds)

        err = api_response['error']
        return nil unless err
        msg = "could not suspend vlan #{id}: #{JSON.dump(err)}"
        fail Puppet::Error, msg
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
        rval = eapi_call('show vlan')
        result = rval['result']
        result.first['vlans']
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
      # @return [String] the decoded response as a hash.
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
      def api
        @api ||= PuppetX::NetDev::EosApi.new(
          address: 'dhcp150.jeff.backline.puppetlabs.net',
          port: 80,
          username: 'admin',
          password: 'puppet')
      end
    end
  end
end
