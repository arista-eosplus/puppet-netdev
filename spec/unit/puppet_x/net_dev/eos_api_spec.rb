# encoding: utf-8

require 'spec_helper'

describe PuppetX::NetDev::EosProviderMethods do
  let(:klass) { Class.new { include PuppetX::NetDev::EosProviderMethods } }
  describe '#api' do
    subject { klass.new.api }

    it { is_expected.to be_a_kind_of PuppetX::NetDev::EosApi }
  end
end

describe PuppetX::NetDev::EosApi do
  # let(:address) { 'dhcp150.jeff.backline.puppetlabs.net' }
  let(:address) { 'localhost' }
  let(:port) { 80 }
  let(:username) { 'admin' }
  let(:password) { 'puppet' }
  let(:config) do
    {
      address: address,
      port: 80,
      username: 'admin',
      password: 'puppet'
    }
  end
  let(:api) { PuppetX::NetDev::EosApi.new(config) }

  ##
  # api_response returns a JSON fixture that presents a representative REST API
  # response.  The method is memoized to reduce filesystem operations.
  #
  # @param [Symbol] key The fixture to load, e.g. :foo will load
  #   'fixture_foo.json'
  def api_response(key)
    memo = Fixtures[key]
    return memo if memo
    file = File.join(File.dirname(__FILE__), "fixture_#{key}.json")
    Fixtures[key] = JSON.load(File.read(file))
  end

  context 'initializing the API instance' do
    [:address, :port, :username, :password].each do |option|
      it "initializes with #{option}" do
        api = described_class.new(option => send(option))
        expect(api.send(option)).to eq(send(option))
      end
    end

    it 'address defaults to /path/to/socket' do
      pending 'unix domain socket path from Arista'
      expect(subject.address).to eq('/path/to/socket')
    end
  end

  describe '#vlan(id)' do
    context 'when the vlan exists' do
      subject { api.vlan(3110) }

      before do
        allow(api).to receive(:eapi_call)
          .with('show vlan 3110', {})
          .and_return(api_response(:show_vlan_3110))
      end

      it 'has only one key' do
        expect(subject.size).to eq 1
      end
      it { is_expected.to be_a_kind_of Hash }
      it { is_expected.to have_key '3110' }
      it { is_expected.not_to have_key 'results' }
    end

    context 'when the vlan does not exist' do
      subject { api.vlan(4000) }

      before do
        allow(api).to receive(:eapi_call)
          .with('show vlan 4000', {})
          .and_return(api_response(:show_vlan_4000))
      end

      it 'raises Puppet:Error with message "could not list vlans"' do
        expect { subject }.to raise_error Puppet::Error, /could not list vlans/
      end
    end
  end

  describe '#vlan_create(id)' do
    subject { api.vlan_create(3100) }

    context 'when eAPI reports no errors' do
      it 'accepts 3100 without error' do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'vlan 3100'], {})
          .and_return(api_response(:create_vlan_success))

        subject
      end
    end

    context 'when eAPI reports errors' do
      before do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'vlan 3100'], {})
          .and_return(api_response(:create_vlan_error))
      end

      it 'raises Puppet::Error on eAPI errors' do
        expect { subject }
          .to raise_error Puppet::Error, /could not create vlan 3100/
      end
    end
  end

  describe '#http' do
    it 'Returns a NetX::HTTPUnix instance' do
      expect(subject.send(:http)).to be_a_kind_of NetX::HTTPUnix
    end

    it 'Attempts to open address unix:///dev/null as a socket' do
      socket_http = described_class.new(address: 'unix:///dev/null').send(:http)
      expect { socket_http.get('/') }.to raise_error Errno::ENOTSOCK
    end
  end

  describe '#format_command' do
    context 'with a single command' do
      subject do
        json = described_class.new.send(:format_command, 'list vlan')
        JSON.parse(json)
      end

      it 'accepts "list vlan" as a single command and returns JSON' do
        expect(subject['params']['cmds']).to eq(['list vlan'])
      end

      it 'generates an ID when an explicit id is not given' do
        expect(subject['id']).not_to be_empty
      end

      it 'uses the explicitly provided ID' do
        json = described_class.new.send(:format_command, 'list vlan', id: 'ID:X')
        expect(JSON.parse(json)['id']).to eq 'ID:X'
      end
    end
  end

  describe '#eapi_request' do
    subject { api.send(:eapi_request, '{}') }

    let :mock_http_post do
      post = double(Net::HTTP::Post)
      allow(post).to receive(:basic_auth)
      post
    end

    before :each do
      allow(Net::HTTP::Post).to receive(:new)
        .with('/command-api/')
        .and_return(mock_http_post)
    end

    it 'sets the body of the post to the string provided' do
      allow(mock_http_post).to receive(:body=).with('{}')
      subject
    end
  end

  describe '#eapi_call' do
    subject { api.send(:eapi_call, 'show vlan') }

    let :api_response_body do
      dir = File.dirname(__FILE__)
      file = File.join(dir, 'fixture_show_vlan.json')
      File.read(file)
    end

    before :each do
      mock_response = double(Net::HTTPOK)
      allow(mock_response).to receive(:body)
        .and_return(api_response_body)

      mock_http = double(NetX::HTTPUnix)
      allow(mock_http).to receive(:request)
        .and_return(mock_response)

      allow(api).to receive(:http).and_return(mock_http)
    end

    it 'decodes the JSON response from the switch' do
      expect(subject).to eq(JSON.parse(api_response_body))
    end
  end

  describe '#eapi_action' do
    before :each do
      mock_response = double(Net::HTTPOK)
      allow(mock_response).to receive(:body)
        .and_return(api_response_body)

      mock_http = double(NetX::HTTPUnix)
      allow(mock_http).to receive(:request)
        .and_return(mock_response)

      allow(api).to receive(:http).and_return(mock_http)
    end

    context 'format: "json" (default)' do
      let :api_response_body do
        dir = File.dirname(__FILE__)
        file = File.join(dir, 'fixture_show_vlan.json')
        File.read(file)
      end

      it 'accepts a human readable description as argument 2' do
        expect(api.send(:eapi_action, 'show vlan', 'show all vlans'))
          .to eq(JSON.parse(api_response_body)['result'])
      end
    end

    context 'format: "text"' do
      let :api_response_body do
        dir = File.dirname(__FILE__)
        json = 'fixture_show_interfaces_switchport_format_text.json'
        file = File.join(dir, json)
        File.read(file)
      end

      it 'accepts a keyword argument of :format => "text"' do
        args = ['show interfaces switchport', 'desc', { format: 'text' }]
        expect(api.send(:eapi_action, *args))
          .to eq(JSON.parse(api_response_body)['result'])
      end
    end
  end

  describe '#all_vlans' do
    subject { api.all_vlans }

    before do
      allow(api).to receive(:eapi_call)
        .with('show vlan', {})
        .and_return(api_response(:show_vlan))
    end

    it { is_expected.to be_a_kind_of Hash }
    it { is_expected.to have_key '1' }
    it { is_expected.to have_key '3110' }
    it { is_expected.not_to have_key 'results' }

    describe '#all_vlans["1"]' do
      subject { api.all_vlans['1'] }

      %w(status name interfaces dynamic).each do |k|
        it { is_expected.to have_key k }
      end
    end
  end

  describe '#all_interfaces' do
    subject { api.all_interfaces }

    before do
      allow(api).to receive(:eapi_call)
        .with('show interfaces', {})
        .and_return(api_response(:show_interfaces))
    end

    it { is_expected.not_to have_key 'results' }
    it { is_expected.to have_key 'Management1' }

    describe '#all_interfaces["Management1"]' do
      subject { api.all_interfaces['Management1'] }

      it { is_expected.to be_a_kind_of Hash }
      it 'has an mtu of 1500' do
        expect(subject['mtu']).to eq 1500
      end
      it 'is hardware ethernet' do
        expect(subject['hardware']).to eq 'ethernet'
      end
      it 'has duplex of duplexFull' do
        expect(subject['duplex']).to eq 'duplexFull'
      end
      it 'has bandwidth of 1000000000' do
        expect(subject['bandwidth']).to eq 1_000_000_000
      end
      it 'has an interfaceAddress key with Array value' do
        expect(subject['interfaceAddress']).to be_an Array
      end
      it 'has a physicalAddress of 00:42:00:6e:00:96' do
        expect(subject['physicalAddress']).to eq '00:42:00:6e:00:96'
      end
    end
  end

  describe '#all_portchannels_detailed' do
    subject { api.all_portchannels_detailed }

    before :each do
      allow(api).to receive(:eapi_call)
        .with('show etherchannel detailed', format: 'text')
        .and_return(api_response(:s4_show_etherchannel_detailed))
    end

    it { is_expected.not_to have_key 'results' }
    it { is_expected.to have_key 'Port-Channel3' }
    it { is_expected.to have_key 'Port-Channel4' }

    describe 'nested attribute hash' do
      subject { api.all_portchannels_detailed['Port-Channel3'] }
      it { is_expected.to have_key 'name' }
      it { is_expected.to have_key 'ports' }

      describe 'ports array' do
        subject { api.all_portchannels_detailed['Port-Channel3']['ports'] }
        it { is_expected.to include('Ethernet1') }
        it { is_expected.to include('Ethernet2') }
        it 'sorts the list of member ports' do
          expect(subject).to eq(subject.sort)
        end
      end
    end
  end

  describe '#all_portchannel_modes' do
    subject { api.all_portchannel_modes }

    context 'with two LAGS, one LACP passive, one active' do
      before :each do
        allow(api).to receive(:eapi_call)
          .with('show port-channel summary', format: 'text')
          .and_return(api_response(:show_port_channel_summary_2_lags))
      end

      let :expected_results do
        {
          'Port-Channel3' => { 'mode' => :passive },
          'Port-Channel4' => { 'mode' => :active }
        }
      end

      it { is_expected.to have_key 'Port-Channel3' }
      it { is_expected.to have_key 'Port-Channel4' }
      it { is_expected.to eq expected_results }
    end

    context 'with one LAG in LACP static mode' do
      before :each do
        allow(api).to receive(:eapi_call)
          .with('show port-channel summary', format: 'text')
          .and_return(api_response(:show_port_channel_summary_static))
      end

      let :expected_results do
        {
          'Port-Channel4' => { 'mode' => :active },
          'Port-Channel9' => { 'mode' => :disabled }
        }
      end

      it { is_expected.to have_key 'Port-Channel4' }
      it { is_expected.to have_key 'Port-Channel9' }
      it { is_expected.to eq expected_results }
    end
  end

  describe '#all_portchannels' do
    subject { api.all_portchannels }

    before :each do
      allow(api).to receive(:all_portchannels_detailed)
        .and_return(fixture(:all_portchannels_detailed))
      allow(api).to receive(:all_portchannel_modes)
        .and_return(fixture(:all_portchannel_modes))
    end

    it { is_expected.to be_a Hash }
    it { is_expected.to have_key 'Port-Channel4' }
    it { is_expected.to have_key 'Port-Channel9' }
    it 'has a mode attribute for each port channel' do
      modes = subject.values.map { |v| v['mode'] }
      expect(modes).to eq %w(active active)
    end
  end

  describe '#channel_group_destroy' do
    let :port_channels_detailed do
      data = {
        'name'  => 'Port-Channel9',
        'ports' => %w(Ethernet1 Ethernet2)
      }
      { 'Port-Channel9' => data }
    end

    before :each do
      allow(api).to receive(:all_portchannels_detailed)
        .and_return(port_channels_detailed)
    end

    it 'removes interfaces from the channel group' do
      expect(api).to receive(:interface_unset_channel_group).with('Ethernet1')
      expect(api).to receive(:interface_unset_channel_group).with('Ethernet2')
      api.channel_group_destroy('Port-Channel9')
    end

    it 'raises ArgumentError when the channel group is unknown' do
      expect { api.channel_group_destroy('Port-Channel1') }
        .to raise_error ArgumentError, /Port-Channel1 is not in \[.*?\]/
    end
  end

  describe '#interface_unset_channel_group' do
    it 'sets no channel-group using the API' do
      cmd = %w(enable configure) << 'interface Ethernet1'
      cmd << 'no channel-group'

      expect(api).to receive(:eapi_action)
        .with(cmd, 'remove Ethernet1 from channel group')

      api.interface_unset_channel_group('Ethernet1')
    end
  end

  describe '#port_channel_destroy' do
    it 'removes the channel interface' do
      cmd = %w(enable configure) << 'no interface Port-Channel1'

      expect(api).to receive(:eapi_action)
        .with(cmd, 'remove Port-Channel1')

      api.port_channel_destroy('Port-Channel1')
    end
  end

  describe '#channel_group_create' do
    context 'with Port-Channel9 and Ethernet1 LACP mode active' do
      it 'sets the interface channel group to active' do
        expect(api).to receive(:interface_set_channel_group)
          .with('Ethernet1', mode: :active, group: 9)

        api.channel_group_create('Port-Channel9',
                                 interfaces: ['Ethernet1'],
                                 mode: :active)
      end
    end
  end

  describe '#interface_set_channel_group' do
    subject do
      api.interface_set_channel_group('Ethernet1', group: 9, mode: mode)
    end
    let(:cmd_prefix) { ['enable', 'configure', 'interface Ethernet1'] }
    let(:msg) { 'join Ethernet1 to channel group 9' }

    context 'when mode is active' do
      let(:mode) { :active }
      let(:config_cmd) { 'channel-group 9 mode active' }

      it 'configures Ethernet1 in group 9 as active' do
        expect(api).to receive(:eapi_action)
          .with([*cmd_prefix, config_cmd], msg)

        subject
      end
    end

    context 'when mode is passive' do
      let(:mode) { :passive }
      let(:config_cmd) { 'channel-group 9 mode passive' }

      it 'configures Ethernet1 in group 9 as passive' do
        expect(api).to receive(:eapi_action)
          .with([*cmd_prefix, config_cmd], msg)

        subject
      end
    end

    context 'when mode is disabled' do
      let(:mode) { :disabled }
      let(:config_cmd) { 'channel-group 9 mode on' }

      it 'configures Ethernet1 in group 9 as static' do
        expect(api).to receive(:eapi_action)
          .with([*cmd_prefix, config_cmd], msg)

        subject
      end
    end

    context 'when mode is invalid' do
      it 'raises ArgumentError' do
        expect { api.interface_set_channel_group('Ethernet1', mode: 'bad') }
          .to raise_error ArgumentError, 'Unknown LACP mode bad'
      end
    end
  end

  describe '#uri' do
    subject { api.uri.to_s }

    context 'with username and password' do
      let :url do
        "http://#{username}:#{password}@#{address}"
      end
      it { is_expected.to eq url }
    end

    context 'without username and password' do
      let(:config) do
        {
          address: 'foo.jeff.backline.puppetlabs.net',
          port: 80
        }
      end
      let :url do
        'http://foo.jeff.backline.puppetlabs.net'
      end

      it { is_expected.to eq url }
    end
  end

  describe '#set_vlan_name' do
    context 'with valid arguments of 3111, "foo"' do
      before do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'vlan 3111', 'name foo'], {})
          .and_return(api_response(:enable_configure_vlan_3111_name_foo))
      end

      it 'names the vlan "foo"' do
        api.set_vlan_name(3111, 'foo')
      end
    end

    context 'with invalid arguments of "foo", "bar"' do
      before do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'vlan foo', 'name bar'], {})
          .and_return(api_response(:enable_configure_vlan_foo_name_bar))
      end

      it 'raises Puppet::Error' do
        expect { api.set_vlan_name('foo', 'bar') }.to raise_error Puppet::Error
      end
    end
  end

  describe '#vlan_destroy' do
    context 'with valid arguments of 3111' do
      let :api_response do
        {
          'jsonrpc' => '2.0',
          'result'  => [{}, {}, {}],
          'id'      => '7af750fd-9324-4f91-b4fb-cedf0c6d6a91'
        }
      end

      before do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'no vlan 3111'], {})
          .and_return(api_response)
      end

      it 'destroys the vlan without raising errors' do
        api.vlan_destroy(3111)
      end
    end

    context 'with invalid arguments of "foo"' do
      let :api_response do
        msg = "CLI command 3 of 3 'no vlan foo' failed: invalid command"
        {
          'jsonrpc' => '2.0',
          'id' => '1cc2e684-2928-4bfe-a86c-7a1397ea05fd',
          'error' => {
            'data' => [
              {},
              {},
              {
                'errors' => ["Invalid input (at token 2: 'foo')"]
              }
            ],
            'message' => msg,
            'code' => 1002
          }
        }
      end

      before do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'no vlan foo'], {})
          .and_return(api_response)
      end

      it 'raises Puppet::Error' do
        expect { api.vlan_destroy('foo') }.to raise_error Puppet::Error
      end
    end
  end

  describe '#set_vlan_state' do
    context 'with valid arguments' do
      let :api_response do
        {
          'jsonrpc' => '2.0',
          'result'  => [{}, {}, {}],
          'id'      => '7af750fd-9324-4f91-b4fb-cedf0c6d6a91'
        }
      end

      it 'returns the API response as a Hash when state is "active"' do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'vlan 3111', 'state active'], {})
          .and_return(api_response)
        api.set_vlan_state(3111, 'active')
      end

      it 'returns the API response as a Hash when state is "suspend"' do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'vlan 3111', 'state suspend'], {})
          .and_return(api_response)
        api.set_vlan_state(3111, 'suspend')
      end
    end

    context 'with invalid arguments' do
      let :api_response do
        msg = "CLI command 4 of 4 'state foo' failed: invalid command"
        {
          'jsonrpc' => '2.0',
          'id' => '1ed4e6ba-89f0-45fa-aeba-f7816b4e7da3',
          'error' => {
            'data' => [
              {},
              {},
              {
                'errors' => ["Invalid input (at token 1: 'foo')"]
              }
            ],
            'message' => msg,
            'code' => 1002
          }
        }
      end

      before do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'vlan 3111', 'state foo'], {})
          .and_return(api_response)
      end

      it 'raises Puppet::Error' do
        expect { api.set_vlan_state(3111, 'foo') }.to raise_error Puppet::Error
      end
    end
  end

  describe '#set_interface_state' do
    context 'with valid arguments' do
      let :api_response do
        {
          'jsonrpc' => '2.0',
          'result'  => [{}, {}, {}],
          'id'      => '7af750fd-9324-4f91-b4fb-cedf0c6d6a91'
        }
      end

      it 'accepts "shutdown"' do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'interface Ethernet1', 'shutdown'], {})
          .and_return(api_response)
        api.set_interface_state('Ethernet1', 'shutdown')
      end

      it 'accepts "no shutdown"' do
        args = ['enable', 'configure', 'interface Ethernet1', 'no shutdown']
        allow(api).to receive(:eapi_call)
          .with(args, {})
          .and_return(api_response)
        api.set_interface_state('Ethernet1', 'no shutdown')
      end
    end
    context 'with invalid arguments' do
      let :api_response do
        {
          'jsonrpc' => '2.0',
          'id' => 'f449e942-940f-499e-989f-74ab4b8b9950',
          'error' => {
            'data' => [
              {},
              {},
              {},
              { 'errors' => ["Invalid input (at token 0: 'garbage')"] }
            ],
            'message' => "CLI command 4 of 4 'garbage' failed: invalid command",
            'code' => 1002
          }
        }
      end

      it 'raises Puppet::Error on an API error' do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'interface Ethernet1', 'garbage'], {})
          .and_return(api_response)
        expect do
          api.set_interface_state('Ethernet1', 'garbage')
        end.to raise_error Puppet::Error
      end
    end
  end

  describe '#set_interface_description' do
    context 'with valid arguments' do
      let :api_response do
        {
          'jsonrpc' => '2.0',
          'result'  => [{}, {}, {}],
          'id'      => '7af750fd-9324-4f91-b4fb-cedf0c6d6a91'
        }
      end

      it 'accepts a non-empty string' do
        preamble = ['enable', 'configure', 'interface Ethernet1']
        allow(api).to receive(:eapi_call)
          .with([*preamble, 'description foobar'], {})
          .and_return(api_response)
        api.set_interface_description('Ethernet1', 'foobar')
      end
    end

    context 'with invalid arguments' do
      let :api_response do
        msg = "CLI command 4 of 4 'description ' failed: invalid command"
        {
          'jsonrpc' => '2.0',
          'id' => 'b2c792ea-f256-42f3-a60d-5a094b29fb0b',
          'error' => {
            'data' => [
              {},
              {},
              {},
              { 'errors' => ['incomplete command (at token 1: None)'] }
            ],
            'message' => msg,
            'code' => 1002
          }
        }
      end

      it 'raises Puppet::Error on an API error' do
        args = ['enable', 'configure', 'interface Ethernet1', 'description ']
        allow(api).to receive(:eapi_call)
          .with(args, {})
          .and_return(api_response)
        expect do
          api.set_interface_description('Ethernet1', '')
        end.to raise_error Puppet::Error, /incomplete command/
      end
    end
  end

  describe '#set_interface_speed' do
    context 'with valid arguments' do
      let :api_response do
        {
          'jsonrpc' => '2.0',
          'result'  => [{}, {}, {}],
          'id'      => '7af750fd-9324-4f91-b4fb-cedf0c6d6a91'
        }
      end

      it 'accepts 1000full' do
        preamble = ['enable', 'configure', 'interface Ethernet1']
        allow(api).to receive(:eapi_call)
          .with([*preamble, 'speed forced 1000full'], {})
          .and_return(api_response)
        api.set_interface_speed('Ethernet1', '1000full')
      end
    end

    context 'when the API returns an error' do
      let :api_response do
        errors = 'Speed and duplex settings are not compatible '\
          'with transceiver for interface Ethernet1.'
        {
          'jsonrpc' => '2.0',
          'id'      => 'd110e10b-a3e9-4378-8361-fd04f1f552fd',
          'error'   => {
            'data' => [
              {},
              {},
              {},
              { 'errors' => [*errors] }
            ],
            'message' => "CLI command 4 of 4 'speed forced 1000full'"\
            ' failed: could not run command',
            'code' => 1000
          }
        }
      end

      it 'raises Puppet::Error with error message from the api' do
        preamble = ['enable', 'configure', 'interface Ethernet1']
        allow(api).to receive(:eapi_call)
          .with([*preamble, 'speed forced 1000full'], {})
          .and_return(api_response)
        expect do
          api.set_interface_speed('Ethernet1', '1000full')
        end.to raise_error Puppet::Error, /not compatible with transceiver/
      end
    end
  end

  describe '#set_interface_mtu' do
    context 'with valid arguments' do
      let :api_response do
        {
          'jsonrpc' => '2.0',
          'result'  => [{}, {}, {}],
          'id'      => '7af750fd-9324-4f91-b4fb-cedf0c6d6a91'
        }
      end

      it 'accepts 9000' do
        preamble = ['enable', 'configure', 'interface Ethernet1']
        allow(api).to receive(:eapi_call)
          .with([*preamble, 'mtu 9000'], {})
          .and_return(api_response)
        api.set_interface_mtu('Ethernet1', 9000)
      end
    end
  end
end

describe 'PuppetX::NetDev::EosProviderMethods' do
  let :fake_provider do
    klass = Class.new do
      include PuppetX::NetDev::EosProviderMethods
      extend PuppetX::NetDev::EosProviderMethods
    end
    klass.new
  end

  describe '#api' do
    subject { fake_provider.api }
    it { is_expected.to be_a PuppetX::NetDev::EosApi }
  end

  describe '#bandwidth_to_speed' do
    it 'converts 10_000_000 to 10m' do
      expect(fake_provider.bandwidth_to_speed(10_000_000)).to eq '10m'
    end
    it 'converts 10_000_000_000 to 10g' do
      expect(fake_provider.bandwidth_to_speed(10_000_000_000)).to eq '10g'
    end
    it 'converts 1_000_000_000 to 1g' do
      expect(fake_provider.bandwidth_to_speed(1_000_000_000)).to eq '1g'
    end
    it 'converts 56_000_000_000 to 56g' do
      expect(fake_provider.bandwidth_to_speed(56_000_000_000)).to eq '56g'
    end
  end

  describe '#duplex_to_value' do
    it 'converts "duplexFull" to :full' do
      expect(fake_provider.duplex_to_value('duplexFull')).to eq :full
    end
    it 'converts "duplexHalf" to :half' do
      expect(fake_provider.duplex_to_value('duplexHalf')).to eq :half
    end
    it 'raises ArgumentError with unknown input' do
      expect do
        fake_provider.duplex_to_value('garbage')
      end.to raise_error ArgumentError
    end
  end

  describe '#interface_status_to_enable' do
    it 'converts "connected" to :true' do
      expect(fake_provider.interface_status_to_enable('connected')).to eq :true
    end
    it 'converts "disabled" to :false' do
      expect(fake_provider.interface_status_to_enable('disabled')).to eq :false
    end
  end

  describe 'interface_attributes' do
    let :attr_hash do
      {
        'interfaceStatus' => 'connected',
        'bandwidth' => 10_000_000_000,
        'duplex' => 'duplexFull'
      }
    end
    subject { fake_provider.interface_attributes(attr_hash) }
    it { is_expected.to be_a_kind_of Hash }
  end
end
