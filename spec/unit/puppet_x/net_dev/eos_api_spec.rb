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
    # Data #vlan is expected to return
    let :expected_result do
      api_response['result'].first['vlans']
    end

    context 'when the vlan exists' do
      subject { api.vlan(3110) }

      # Data the mock API call returns
      let :api_response do
        dir = File.dirname(__FILE__)
        file = File.join(dir, 'fixture_show_vlan_3110.json')
        JSON.load(File.read(file))
      end

      before do
        allow(api).to receive(:eapi_call)
          .with('show vlan 3110')
          .and_return(api_response)
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

      # Data the mock API call returns
      let :api_response do
        dir = File.dirname(__FILE__)
        file = File.join(dir, 'fixture_show_vlan_4000.json')
        JSON.load(File.read(file))
      end

      before do
        allow(api).to receive(:eapi_call)
          .with('show vlan 4000')
          .and_return(api_response)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#vlan_create(id)' do
    subject { api.vlan_create(3100) }

    before :all do
      dir = File.dirname(__FILE__)
      good = File.join(dir, 'fixture_create_vlan_success.json')
      @api_response_ok = JSON.load(File.read(good))
      bad = File.join(dir, 'fixture_create_vlan_error.json')
      @api_response_error = JSON.load(File.read(bad))
    end

    context 'when eAPI reports no errors' do
      before do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'vlan 3100'])
          .and_return(@api_response_ok)
      end

      it { is_expected.to eq(true) }
    end

    context 'when eAPI reports errors' do
      before do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'vlan 3100'])
          .and_return(@api_response_error)
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
      expect(-> { socket_http.get('/') }).to raise_error Errno::ENOTSOCK
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
        json = described_class.new.send(:format_command, 'list vlan', 'ID:X')
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

  describe '#all_vlans' do
    subject { api.all_vlans }

    # Data the mock API call returns
    let :api_response do
      dir = File.dirname(__FILE__)
      file = File.join(dir, 'fixture_show_vlan.json')
      JSON.load(File.read(file))
    end

    # Data all_vlans is expected to return
    let :vlans do
      api_response['result'].first['vlans']
    end

    before do
      allow(api).to receive(:eapi_call)
        .with('show vlan')
        .and_return(api_response)
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
          address: 'dhcp150.jeff.backline.puppetlabs.net',
          port: 80
        }
      end
      let :url do
        'http://dhcp150.jeff.backline.puppetlabs.net'
      end

      it { is_expected.to eq url }
    end
  end

  describe '#set_vlan_name' do
    context 'with valid arguments of 3111, "foo"' do
      let :api_response do
        dir = File.dirname(__FILE__)
        file = 'fixture_enable_configure_vlan_3111_name_foo.json'
        file_path = File.join(dir, file)
        JSON.load(File.read(file_path))
      end

      before do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'vlan 3111', 'name foo'])
          .and_return(api_response)
      end

      it 'names the vlan "foo"' do
        api.set_vlan_name(3111, 'foo')
      end
    end

    context 'with invalid arguments of "foo", "bar"' do
      let :api_response do
        dir = File.dirname(__FILE__)
        file = 'fixture_enable_configure_vlan_foo_name_bar.json'
        file_path = File.join(dir, file)
        JSON.load(File.read(file_path))
      end

      before do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'vlan foo', 'name bar'])
          .and_return(api_response)
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
          .with(['enable', 'configure', 'no vlan 3111'])
          .and_return(api_response)
      end

      it 'returns nil' do
        expect(api.vlan_destroy(3111)).to be_nil
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
          .with(['enable', 'configure', 'no vlan foo'])
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

      it 'returns nil when state is "active"' do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'vlan 3111', 'state active'])
          .and_return(api_response)
        expect(api.set_vlan_state(3111, 'active')).to be_nil
      end

      it 'returns nil when state is "suspend"' do
        allow(api).to receive(:eapi_call)
          .with(['enable', 'configure', 'vlan 3111', 'state suspend'])
          .and_return(api_response)
        expect(api.set_vlan_state(3111, 'suspend')).to be_nil
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
          .with(['enable', 'configure', 'vlan 3111', 'state foo'])
          .and_return(api_response)
      end

      it 'raises Puppet::Error' do
        expect { api.set_vlan_state(3111, 'foo') }.to raise_error Puppet::Error
      end
    end
  end
end
