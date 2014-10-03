# encoding: utf-8

require 'spec_helper'

describe Puppet::Type.type(:port_channel).provider(:eos) do
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
      name: 'Port-Channel9',
      id: 9,
      provider: described_class.name
    }
    Puppet::Type.type(:port_channel).new(resource_hash)
  end

  let :resources do
    { resource.name => resource }
  end

  let(:provider) { resource.provider }

  context 'class methods' do
    before :each do
      allow(described_class.api).to receive(:all_portchannels)
        .and_return(fixture(:api_all_portchannels))
      allow(described_class.api).to receive(:all_interfaces)
        .and_return(fixture(:api_all_interfaces))
    end

    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }
      it 'has two instances' do
        expect(subject.size).to eq(2)
      end
      it 'contains only provider instances' do
        subject.each do |instance|
          expect(instance).to be_a described_class
        end
      end
      it 'has name set for all providers' do
        names = subject.map(&:name)
        expect(names).to eq %w(Port-Channel4 Port-Channel9)
      end
      it 'containes only providers instances with ensure => present' do
        subject.each do |instance|
          expect(instance.ensure).to eq(:present)
        end
      end
      it 'has the id parameter set for all providers' do
        ids = subject.map(&:id)
        expect(ids).to eq([4, 9])
      end
      it 'has interfaces set for all providers' do
        subject.each { |p| expect(p.interfaces).not_to be_empty }
      end
      it 'has mode set for all providers' do
        subject.each { |p| expect(p.mode).to eq 'active' }
      end
    end

    describe '.prefetch' do
      subject { described_class.prefetch(resources) }

      it 'binds the provider instance to the catalog resource' do
        expect(resource).to receive(:provider=)
        subject
      end

      it 'modifies the passed in resources object' do
        provider1 = resources.values.first.provider
        subject
        provider2 = resources.values.first.provider

        expect(provider1).not_to be provider2
      end
    end
  end
end
