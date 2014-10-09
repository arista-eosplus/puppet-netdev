# encoding: utf-8

require 'spec_helper'

describe Puppet::Type.type(:snmp_community).provider(:eos) do
  let(:type) { Puppet::Type.type(:snmp_community) }

  # Allow text cases to override resource attributes
  let :resource_override do
    {}
  end

  let :resource_hash do
    {
      name: 'public',
      ensure: :present,
      group: 'ro',
      acl: 'Public Community'
    }.merge(resource_override)
  end


  let(:resource) { type.new(resource_hash) }
  let(:provider) { described_class.new(resource) }

  before :each do
    allow(described_class.api).to receive(:snmp_communities)
      .and_return(fixture(:api_snmp_communities))
  end

  describe 'class methods' do
    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }
      it { expect(subject.size).to eq(3) }

      it 'each provider has ensure=present' do
        subject.each { |p| expect(p.ensure).to eq(:present) }
      end
    end
  end

  describe '#create' do
    subject { provider.create }
    before :each do
      allow(provider.api).to receive(:snmp_community_create)
    end

    it 'calls api.snmp_community_create' do
      expect(provider.api).to receive(:snmp_community_create)
        .with(name: 'public', group: :ro, acl: 'Public Community')
      subject
    end

    it 'sets the ensure value to :present' do
      subject
      expect(provider.ensure).to eq :present
    end

    it 'sets the group to :ro' do
      subject
      expect(provider.group).to eq :ro
    end

    it 'sets the acl to "Public Community"' do
      subject
      expect(provider.acl).to eq 'Public Community'
    end
  end

  describe '#group=(value)' do
  end

  describe '#acl=(value)' do
  end

  describe '#exists?' do
    let(:provider) { described_class.new(resource_hash) }
    subject { provider.exists? }

    context 'when ensure is absent' do
      let(:resource_override) { { ensure: :absent } }
      it { is_expected.to eq(false) }
    end

    context 'when ensure is present' do
      let(:resource_override) { { ensure: :present } }
      it { is_expected.to eq(true) }
    end
  end
end
