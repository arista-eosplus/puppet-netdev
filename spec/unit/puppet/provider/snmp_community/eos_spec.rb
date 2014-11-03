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

  describe '#flush' do
    before :each do
      allow(provider.api).to receive(:snmp_community_set)
      allow(provider.api).to receive(:snmp_community_destroy)
    end

    context 'after create' do
      subject do
        provider.create
        provider.flush
      end

      it 'calls api.snmp_community_set' do
        expected_args = {
          name: 'public',
          group: :ro,
          acl: 'Public Community',
          ensure: :present
        }
        expect(provider.api).to receive(:snmp_community_set)
          .with(expected_args)
        subject
      end

      it 'sets the ensure value to :present' do
        subject
        expect(provider.ensure).to eq(:present)
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

    context 'after destroy' do
      subject do
        provider.destroy
        provider.flush
      end

      it 'calls api.snmp_community_set' do
        expect(provider.api).to receive(:snmp_community_destroy)
          .with(name: 'public')
        subject
      end

      it 'sets the ensure value to :absent' do
        subject
        expect(provider.ensure).to eq(:absent)
      end
    end

    context 'when changing the group' do
      let(:provider) { described_class.new(resource_hash) }
      let :expected_args do
        resource_hash.merge(group: 'rw', acl: 'Public Community')
      end

      it 'does not unset the acl' do
        provider.group = 'rw'
        expect(provider.api).to receive(:snmp_community_set)
          .with(expected_args)
        provider.flush
      end
    end
  end

  describe '#create' do
    subject { provider.create }

    it 'sets @property_flush with ensure: present' do
      subject
      expect(provider.instance_variable_get(:@property_flush))
        .to include(ensure: :present)
    end

    it 'sets @property_flush with group: :ro' do
      subject
      expect(provider.instance_variable_get(:@property_flush))
        .to include(group: :ro)
    end

    it 'sets @property_flush with acl: "Public Community"' do
      subject
      expect(provider.instance_variable_get(:@property_flush))
        .to include(acl: 'Public Community')
    end

    it 'sets @property_flush with name: "public"' do
      subject
      expect(provider.instance_variable_get(:@property_flush))
        .to include(name: 'public')
    end
  end

  describe '#destroy' do
    subject { provider.destroy }

    it 'sets @property_flush with ensure: absent' do
      subject
      expect(provider.instance_variable_get(:@property_flush))
        .to include(ensure: :absent)
    end
  end

  describe '#group=(value)' do
    subject { provider.group = val }

    [:ro, :rw].each do |value|
      context "#group = #{value.inspect}" do
        let(:val) { value }

        it "sets @property_flush[:group] = #{value.inspect}" do
          subject
          expect(provider.instance_variable_get(:@property_flush))
            .to include(group: value)
        end
      end
    end
  end

  describe '#acl=(value)' do
    subject { provider.acl = val }

    %w(stest1 stest2 foo).each do |value|
      context "#acl = #{value.inspect}" do
        let(:val) { value }

        it "sets @property_flush[:acl] = #{value.inspect}" do
          subject
          expect(provider.instance_variable_get(:@property_flush))
            .to include(acl: value)
        end
      end
    end
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
