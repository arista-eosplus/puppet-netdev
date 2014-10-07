# encoding: utf-8

require 'spec_helper'

# SnmpMethods should be mixed into the EosApi class
describe PuppetX::NetDev::EosApi do
  let(:api) { PuppetX::NetDev::EosApi.new }

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
end
