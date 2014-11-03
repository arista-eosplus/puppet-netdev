# encoding: utf-8

require 'spec_helper'

describe Puppet::Type.type(:network_snmp).provider(:eos) do
  let(:type) { Puppet::Type.type(:network_snmp) }

  let :resource do
    resource_hash = {
      name: 'settings',
      enable: :true,
      location: 'Planet Earth',
      contact: 'Jane Doe'
    }
    type.new(resource_hash)
  end

  let(:provider) { resource.provider }

  before :each do
    allow(described_class.api).to receive(:snmp_attributes)
      .and_return(fixture(:snmp_attributes))
  end

  context 'class methods' do
    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }

      it 'has one instance' do
        expect(subject.size).to eq(1)
      end

      it 'contains Network_snmp[settings]' do
        instance = subject.find { |p| p.name == 'settings' }
        expect(instance).to be_a described_class
      end

      describe 'Network_snmp[settings]' do
        subject { described_class.instances.find { |p| p.name == 'settings' } }

        include_examples 'provider resource methods',
                         name: 'settings',
                         enable: :true,
                         contact: 'Jane Doe',
                         location: 'Planet Earth',
                         exists?: true
      end
    end

    describe '.prefetch' do
      let(:resources) { { 'settings' => type.new(name: 'settings') } }
      subject { described_class.prefetch(resources) }

      it 'updates the provider instance of managed resources' do
        expect(resources['settings'].provider.contact).to eq(:absent)
        subject
        expect(resources['settings'].provider.contact).to eq('Jane Doe')
      end
    end

    describe '#enable=' do
      subject { provider.enable = value }

      before :each do
        allow(provider.api).to receive(:snmp_enable=)
      end

      context 'when #enable=(:true)' do
        let(:value) { :true }

        it 'calls api.snmp_enable=true' do
          expect(provider.api).to receive(:snmp_enable=).with(true)
          subject
        end

        it 'sets enable to :true in the provider' do
          expect(provider.enable).not_to eq(:true)
          subject
          expect(provider.enable).to eq(:true)
        end
      end

      context 'when #enable=(:false)' do
        let(:value) { :false }

        it 'calls api.snmp_enable=false' do
          expect(provider.api).to receive(:snmp_enable=).with(false)
          subject
        end

        it 'sets enable to :true in the provider' do
          expect(provider.enable).not_to eq(:true)
          subject
          expect(provider.enable).to eq(:false)
        end
      end
    end

    describe '#contact=' do
      subject { provider.contact = 'John Doe' }

      before :each do
        allow(provider.api).to receive(:snmp_contact=)
      end

      it 'calls api.snmp_contact = "John Doe"' do
        expect(provider.api).to receive(:snmp_contact=).with('John Doe')
        subject
      end

      it 'sets contact to "John Doe" in the provider' do
        expect(provider.contact).not_to eq('John Doe')
        subject
        expect(provider.contact).to eq('John Doe')
      end
    end

    describe '#location=' do
      subject { provider.location = 'Planet Earth' }

      before :each do
        allow(provider.api).to receive(:snmp_location=)
      end

      it 'calls api.snmp_location = "Planet Earth"' do
        expect(provider.api).to receive(:snmp_location=).with('Planet Earth')
        subject
      end

      it 'sets location to "Planet Earth" in the provider' do
        expect(provider.location).not_to eq('Planet Earth')
        subject
        expect(provider.location).to eq('Planet Earth')
      end
    end
  end
end
