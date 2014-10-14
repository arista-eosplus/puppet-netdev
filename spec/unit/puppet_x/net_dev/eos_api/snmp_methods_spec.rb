# encoding: utf-8

require 'spec_helper'

# SnmpMethods should be mixed into the EosApi class
describe PuppetX::NetDev::EosApi do
  let(:api) { PuppetX::NetDev::EosApi.new }
  let(:prefix) { %w(enable configure) }

  describe '#snmp_attributes' do
    subject { api.snmp_attributes }
    before :each do
      allow(api).to receive(:snmp_location).and_return(location: 'foo')
      allow(api).to receive(:snmp_enable).and_return(enable: :true)
      allow(api).to receive(:snmp_contact).and_return(contact: 'Jane Doe')
    end

    it { is_expected.to have_key :ensure }
    it { is_expected.to have_key :name }
    it { is_expected.to have_key :enable }
    it { is_expected.to have_key :contact }
    it { is_expected.to have_key :location }

    it 'merges attributes into a single hash' do
      expect(subject).to eq(ensure: :present,
                            name: 'settings',
                            enable: :true,
                            contact: 'Jane Doe',
                            location: 'foo')
    end
  end

  describe '#snmp_location' do
    subject { api.snmp_location }

    context 'when location is empty on the device' do
      before :each do
        allow(api).to receive(:eapi_action)
          .with('show snmp location', 'get snmp location')
          .and_return(fixture(:show_snmp_location_empty))
      end

      it { is_expected.to be_a Hash }
      it { is_expected.to have_key :location }
      it ':location is empty' do
        expect(subject[:location]).to be_empty
      end
    end

    context 'when location is present on the device' do
      before :each do
        allow(api).to receive(:eapi_action)
          .with('show snmp location', 'get snmp location')
          .and_return(fixture(:get_snmp_location_westeros))
      end

      it { is_expected.to be_a Hash }
      it { is_expected.to have_key :location }
      it ':location is empty' do
        expect(subject[:location]).to eq 'Westeros'
      end
    end
  end

  describe '#snmp_enable' do
    subject { api.snmp_enable }

    context 'when SNMP is disabled' do
      before :each do
        allow(api).to receive(:eapi_action)
          .with('show snmp', 'get snmp status', format: 'text')
          .and_return(fixture(:show_snmp_disabled))
      end

      it { is_expected.to be_a Hash }
      it { is_expected.to have_key :enable }
      it ':enable => :false' do
        expect(subject[:enable]).to eq(:false)
      end
    end

    context 'when SNMP is enabled' do
      before :each do
        allow(api).to receive(:eapi_action)
          .with('show snmp', 'get snmp status', format: 'text')
          .and_return(fixture(:show_snmp_enabled))
      end

      it { is_expected.to be_a Hash }
      it { is_expected.to have_key :enable }
      it ':enable => :true' do
        expect(subject[:enable]).to eq(:true)
      end
    end
  end

  describe '#parse_snmp_enable(text)' do
    context 'when garbage is provided' do
      subject { api.parse_snmp_enable('garbage') }

      it 'throws an ArgumentError' do
        expect { subject }.to raise_error ArgumentError, /could not parse/
      end
    end

    context 'when text contains "SNMP agent disabled:"' do
      subject { api.parse_snmp_enable('SNMP agent disabled:') }
      it { is_expected.to eq(:false) }
    end

    context 'when text contains "SNMP packets input"' do
      subject { api.parse_snmp_enable('SNMP packets input') }
      it { is_expected.to eq(:true) }
    end
  end

  describe '#snmp_contact' do
    subject { api.snmp_contact }

    context 'when the contact is empty' do
      before :each do
        allow(api).to receive(:eapi_action)
          .with('show snmp contact', 'get snmp contact')
          .and_return(fixture(:show_snmp_contact_empty))
      end

      it { is_expected.to be_a Hash }
      it { is_expected.to have_key :contact }
      it ':contact => ""' do
        expect(subject[:contact]).to eq('')
      end
    end

    context 'when the contact is "Jane Doe"' do
      before :each do
        allow(api).to receive(:eapi_action)
          .with('show snmp contact', 'get snmp contact')
          .and_return(fixture(:show_snmp_contact_name))
      end

      it { is_expected.to be_a Hash }
      it { is_expected.to have_key :contact }
      it ':contact => "Jane Doe"' do
        expect(subject[:contact]).to eq('Jane Doe')
      end
    end
  end

  describe '#snmp_enable=(state)' do
    context 'when state is true' do
      subject { api.snmp_enable = true }
      let(:expected) { 'snmp-server community public ro' }

      it 'enables snmp by setting a public community string to ro' do
        expect(api).to receive(:eapi_action)
          .with(['enable', 'configure', expected], 'configure snmp')
          .and_return([{}, {}, {}])
        subject
      end
    end

    context 'when state is false' do
      subject { api.snmp_enable = false }
      let(:expected) { 'no snmp-server' }

      it 'disables snmp by setting no snmp-server' do
        expect(api).to receive(:eapi_action)
          .with(['enable', 'configure', expected], 'configure snmp')
          .and_return([{}, {}, {}])
        subject
      end
    end

    context 'when state is :garbage' do
      subject { api.snmp_enable = :garbage }
      it { expect { subject }.to raise_error ArgumentError, /invalid state/ }
    end
  end

  describe '#snmp_contact=(contact)' do
    subject { api.snmp_contact = 'Jane Doe' }
    it 'sets the contact using snmp-server contact Jane Doe' do
      expect(api).to receive(:eapi_action)
        .with(['enable', 'configure', 'snmp-server contact Jane Doe'],
              'set snmp contact')
        .and_return([{}, {}, {}])
      subject
    end
  end

  describe '#snmp_location=(location)' do
    subject { api.snmp_location = 'Planet Earth' }
    it 'sets the contact using snmp-server location Planet Earth' do
      expect(api).to receive(:eapi_action)
        .with(['enable', 'configure', 'snmp-server location Planet Earth'],
              'set snmp location')
        .and_return([{}, {}, {}])
      subject
    end
  end

  describe '#snmp_communities' do
    subject { api.snmp_communities }

    before :each do
      allow(api).to receive(:eapi_action)
        .with('show snmp community', 'get snmp communities', format: 'text')
        .and_return(example_api_response)
    end

    describe 'structure of the return object' do
      let(:example_api_response) { fixture(:show_snmp_community) }

      it { is_expected.to be_an Array }
      it 'is expected to have 3 results' do
        expect(subject.size).to eq(3)
      end
    end

    context 'when there is a community with an existing acl' do
      let(:example_api_response) { fixture(:show_snmp_community) }

      it { is_expected.to include(name: 'jeff', group: 'rw', acl: 'stest1') }
      it { is_expected.to include(name: 'public', group: 'ro') }
      it { is_expected.to include(name: 'private', group: 'rw') }
    end

    context 'when there is a community with a non-existent acl' do
      let(:example_api_response) do
        fixture(:get_snmp_communities_non_existent_acl)
      end

      it 'has 6 results' do
        expect(subject.size).to eq(6)
      end
      it { is_expected.to include(name: 'jeff', group: 'rw', acl: 'stest1') }
      it { is_expected.to include(name: 'jeff2', group: 'ro', acl: 'stest1') }
      it { is_expected.to include(name: 'jeff3', group: 'ro', acl: 'stest1') }
      it 'parses "Access list: stest2 (non-existent)" as stest2' do
        expect(subject).to include(name: 'jeff4', group: 'ro', acl: 'stest2')
      end
      it { is_expected.to include(name: 'public', group: 'ro') }
      it { is_expected.to include(name: 'private', group: 'rw') }
    end
  end

  describe '#snmp_community_set' do
    subject { api.snmp_community_set(resource_hash) }
    let(:prefix) { %w(enable configure) }

    context 'when the api call succeeds' do
      before :each do
        allow(api).to receive(:eapi_action).and_return(true)
      end

      let :resource_hash do
        { name: 'public', group: :ro, acl: 'stest1' }
      end

      it { is_expected.to eq(true) }
    end

    context 'group and acl are both set' do
      let :resource_hash do
        { name: 'public', group: :ro, acl: 'stest1' }
      end

      it 'sets the group and the acl in that positional order' do
        expected = 'snmp-server community public ro stest1'
        expect(api).to receive(:eapi_action)
          .with([*prefix, expected], 'define snmp community')
        subject
      end
    end

    context 'group is set, acl is not set' do
      let :resource_hash do
        { name: 'public', group: :ro }
      end

      it 'sets the group and not the acl' do
        expected = 'snmp-server community public ro'
        expect(api).to receive(:eapi_action)
          .with([*prefix, expected], 'define snmp community')
        subject
      end
    end

    context 'group is not set, acl is set' do
      let :resource_hash do
        { name: 'public', acl: 'stest1' }
      end

      it 'sets the acl and not the group' do
        expected = 'snmp-server community public stest1'
        expect(api).to receive(:eapi_action)
          .with([*prefix, expected], 'define snmp community')
        subject
      end
    end
  end

  describe '#snmp_community_destroy' do
    subject { api.snmp_community_destroy(resource_hash) }
    let(:prefix) { %w(enable configure) }

    let :resource_hash do
      { name: 'public' }
    end

    context 'when the api call succeeds' do
      before :each do
        allow(api).to receive(:eapi_action).and_return(true)
      end

      it { is_expected.to eq(true) }
    end

    describe 'expected REST API call' do
      it 'calls eapi_action with []' do
        expected = [[*prefix, 'no snmp-server community public'],
                    'destroy snmp community']
        expect(api).to receive(:eapi_action)
          .with(*expected)
          .and_return(true)

        subject
      end
    end
  end

  describe '#snmp_notifications' do
    subject { api.snmp_notifications }

    before :each do
      allow(api).to receive(:eapi_action)
        .with('show snmp trap', 'get snmp traps', format: 'text')
        .and_return(fixture(:show_snmp_trap))
    end

    it { is_expected.to be_an Array }
    it 'parses 23 resources' do
      expect(subject.size).to eq(23)
    end
    describe 'disabled notifications' do
      it 'includes msdp backward-transition' do
        expect(subject).to include(name: 'msdp backward-transition',
                                   enable: :false)
      end
      it { is_expected.to include(name: 'pim neighbor-loss', enable: :false) }
    end
  end

  describe '#snmp_notification_set' do
    subject { api.snmp_notification_set(resource_hash) }

    before :each do
      allow(api).to receive(:eapi_action).and_return([{}, {}, {}])
    end

    context 'when :enable => :true' do
      let :resource_hash do
        { name: 'snmp link-down', enable: :true }
      end

      it { is_expected.to eq(true) }

      it 'executes "snmp-server enable traps snmp link-down"' do
        expect(api).to receive(:eapi_action)
          .with([*prefix, 'snmp-server enable traps snmp link-down'],
                'set snmp trap')
        subject
      end
    end

    context 'when :enable => :false' do
      let :resource_hash do
        { name: 'snmp link-down', enable: :false }
      end

      it { is_expected.to eq(true) }

      it 'executes "no snmp-server enable traps snmp link-down"' do
        expect(api).to receive(:eapi_action)
          .with([*prefix, 'no snmp-server enable traps snmp link-down'],
                'set snmp trap')
        subject
      end
    end

    context 'when :name => "all" (manage all traps)' do
      context 'when :enable => :true' do
        let :resource_hash do
          { name: 'all', enable: :true }
        end

        it { is_expected.to eq(true) }

        it 'executes "snmp-server enable traps"' do
          expect(api).to receive(:eapi_action)
            .with([*prefix, 'snmp-server enable traps'],
                  'set snmp trap')
          subject
        end
      end

      context 'when :enable => :false' do
        let :resource_hash do
          { name: 'all', enable: :false }
        end

        it { is_expected.to eq(true) }

        it 'executes "no snmp-server enable traps"' do
          expect(api).to receive(:eapi_action)
            .with([*prefix, 'no snmp-server enable traps'],
                  'set snmp trap')
          subject
        end
      end
    end
  end
end
