# encoding: utf-8

require 'spec_helper'

describe Puppet::Type.type(:network_vlan).provider(:eos) do
  # EOS API Memoized Methods
  let(:address) { 'localhost' }
  let(:port) { 80 }
  let(:username) { 'admin' }
  let(:password) { 'puppet' }
  let(:config) do
    {
      address: address,
      port: port,
      username: username,
      password: password
    }
  end

  # Puppet RAL memoized methods
  let(:resource) do
    resource_hash = {
      ensure: :present,
      name: '100',
      vlan_name: 'VLAN100',
      shutdown: false,
      provider: described_class.name
    }
    Puppet::Type.type(:network_vlan).new(resource_hash)
  end

  let(:provider) { resource.provider }

  def all_vlans
    all_vlans = Fixtures[:all_vlans]
    return all_vlans if all_vlans
    file = File.join(File.dirname(__FILE__), 'fixture_api_all_vlans.json')
    Fixtures[:all_vlans] = JSON.load(File.read(file))
  end

  # Stub the Api method class to obtain all vlans.
  before :each do
    allow(described_class.api).to receive(:all_vlans).and_return(all_vlans)
  end

  context 'class methods' do
    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }
      it 'has two instances' do
        expect(subject.size).to eq(2)
      end

      %w(1 3110).each do |name|
        it "has an instance for VLAN #{name}" do
          instance = subject.find { |p| p.name == name }
          expect(instance).to be_a described_class
        end
      end

      context 'network_vlan { 3110: }' do
        subject { described_class.instances.find { |p| p.name == '3110' } }

        include_examples 'provider resource methods',
                         ensure: :present,
                         id: 3110,
                         vlan_name: 'VLAN3110',
                         shutdown: :false,
                         description: :absent,
                         exists?: true
      end

      context 'network_vlan { 1: }' do
        subject { described_class.instances.find { |p| p.name == '1' } }

        include_examples 'provider resource methods',
                         ensure: :present,
                         id: 1,
                         vlan_name: 'default',
                         shutdown: :false,
                         description: :absent,
                         exists?: true
      end
    end

    describe '.prefetch' do
      let :resources do
        {
          '1' => Puppet::Type.type(:network_vlan).new(name: '1'),
          '2' => Puppet::Type.type(:network_vlan).new(name: '2')
        }
      end
      subject { described_class.prefetch(resources) }

      it 'resource providers are absent prior to calling .prefetch' do
        resources.values.each do |rsrc|
          expect(rsrc.provider.id).to eq(:absent)
          expect(rsrc.provider.vlan_name).to eq(:absent)
        end
      end

      it 'sets the provider instance of the managed resource' do
        subject
        expect(resources['1'].provider.id).to eq(1)
        expect(resources['1'].provider.vlan_name).to eq('default')
        expect(resources['1'].provider.exists?).to eq(true)
      end

      it 'does not set the provider instance of the unmanaged resource' do
        subject
        expect(resources['2'].provider.id).to eq(:absent)
        expect(resources['2'].provider.vlan_name).to eq(:absent)
        expect(resources['2'].provider.exists?).to eq(false)
      end
    end
  end

  context 'resource (instance) methods' do
    describe '#exists?' do
      subject { provider.exists? }

      context 'when the resource does not exist on the system' do
        it { is_expected.to eq(false) }
      end

      context 'when the resource exists on the system' do
        let(:provider) { described_class.instances.first }
        it { is_expected.to eq(true) }
      end
    end

    describe '#create' do
      before :each do
        allow(provider.api).to receive(:vlan_create)
          .with(provider.resource[:id])
      end

      it 'calls EosApi#vlan_create(id) with the resource id' do
        expect(provider.api).to receive(:vlan_create)
          .with(provider.resource[:id])
        provider.create
      end

      it 'sets ensure to :present' do
        provider.create
        expect(provider.ensure).to eq(:present)
      end

      it 'sets shutdown to the resource value' do
        provider.create
        expect(provider.shutdown).to eq(provider.resource[:shutdown])
      end

      it 'sets vlan_name to the resource value' do
        provider.create
        expect(provider.vlan_name).to eq(provider.resource[:vlan_name])
      end
    end

    describe '#destroy' do
      before :each do
        allow(provider.api).to receive(:vlan_create)
          .with(provider.resource[:id])
        allow(provider.api).to receive(:vlan_destroy)
          .with(provider.resource[:id])
      end

      it 'calls EosApi#vlan_destroy(id)' do
        expect(provider.api).to receive(:vlan_destroy)
          .with(provider.resource[:id])
        provider.destroy
      end

      context 'when the resource has been created' do
        subject do
          provider.create
          provider.destroy
        end

        it 'sets ensure to :absent' do
          subject
          expect(provider.ensure).to eq(:absent)
        end

        it 'clears the property hash' do
          subject
          expect(provider.instance_variable_get(:@property_hash))
            .to eq(id: '100', ensure: :absent)
        end
      end
    end

    describe '#vlan_name=(value)' do
      before :each do
        allow(provider.api).to receive(:set_vlan_name)
          .with(provider.resource[:id], 'foo')
      end

      it 'calls EosApi#set_vlan_name("100", "foo")' do
        expect(provider.api).to receive(:set_vlan_name)
          .with(provider.resource[:id], 'foo')
        provider.vlan_name = 'foo'
      end

      it 'updates vlan_name in the provider' do
        expect(provider.vlan_name).not_to eq('foo')
        provider.vlan_name = 'foo'
        expect(provider.vlan_name).to eq('foo')
      end
    end

    describe '#shutdown=(value)' do
      before :each do
        allow(provider.api).to receive(:set_vlan_state)
      end

      subject { provider.shutdown = state }

      context 'when value is :true' do
        let!(:state) { :true }

        it 'calls EosApi#set_vlan_state("100", "suspend")' do
          expect(provider.api).to receive(:set_vlan_state)
            .with(provider.resource[:id], 'suspend')
          subject
        end
      end

      context 'when value is :false' do
        let!(:state) { :false }

        it 'calls EosApi#set_vlan_state("100", "active")' do
          expect(provider.api).to receive(:set_vlan_state)
            .with(provider.resource[:id], 'active')
          subject
        end
      end

      context 'when value is :garbage' do
        let!(:state) { :garbage }

        it 'raises Puppet::Error' do
          expect { subject }.to raise_error Puppet::Error
        end
      end
    end
  end
end
