require 'spec_helper'

describe Puppet::Type.type(:ntp_config).provider(:eos) do
  let(:type) { Puppet::Type.type(:ntp_config) }

  let :resource do
    resource_hash = {
      name: 'settings',
      source_interface: 'Loopback0'
    }
    type.new(resource_hash)
  end

  let(:provider) { resource.provider }

  def ntp
    ntp = Fixtures[:ntp]
    return ntp if ntp
    file = File.join(File.dirname(__FILE__), 'fixture_ntp.json')
    Fixtures[:ntp] = JSON.load(File.read(file))
  end

  before :each do
    allow_message_expectations_on_nil
    allow(described_class).to receive(:eapi)
    allow(described_class.eapi).to receive(:Ntp)
    allow(described_class.eapi.Ntp).to receive(:get)
      .and_return(ntp)
  end

  context 'class methods' do
    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }

      it 'has one instance' do
        expect(subject.size).to eq(1)
      end

      it 'contains Eos_ntp_config[settings]' do
        instance = subject.find { |p| p.name == 'settings' }
        expect(instance).to be_a described_class
      end

      describe 'Eos_ntp_config[settings]' do
        subject do
          described_class.instances.find { |p| p.name == 'settings' }
        end

        include_examples 'provider resource methods',
                         name: 'settings',
                         source_interface: 'Loopback0'
      end
    end

    describe '.prefetch' do
      let(:resources) { { 'settings' => type.new(name: 'settings') } }
      subject { described_class.prefetch(resources) }

      it 'updates the provider instance of managed resources' do
        expect(resources['settings'].provider.source_interface).to \
          eq(:absent)
        subject
        expect(resources['settings'].provider.source_interface).to \
          eq('Loopback0')
      end
    end
  end

  context 'resource (instance) methods' do

    let(:eapi) { double }

    before do
      allow(provider).to receive(:eapi)
      allow(provider.eapi).to receive(:Ntp)
    end

    describe '#source_interface=(val)' do
      subject { provider.source_interface = 'Loopback0' }

      before :each do
        allow(provider.eapi.Ntp).to receive(:set_source_interface)
          .with(value: 'Loopback0')
      end

      it 'calls Ntp.set_source_interface = "Loopback0"' do
        expect(provider.eapi.Ntp).to receive(:set_source_interface)
          .with(value: 'Loopback0')
        subject
      end

      it 'sets source_interface to "Loopback0" in the provider' do
        expect(provider.source_interface).not_to eq('Loopback0')
        subject
        expect(provider.source_interface).to eq('Loopback0')
      end
    end
  end
end
