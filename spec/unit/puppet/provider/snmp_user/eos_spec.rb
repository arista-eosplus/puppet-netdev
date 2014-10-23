# encoding: utf-8

require 'spec_helper'

describe Puppet::Type.type(:snmp_user).provider(:eos) do
  let(:type) { Puppet::Type.type(:snmp_user) }

  # Allow text cases to override resource attributes
  let :resource_override do
    {}
  end

  let :resource_hash do
    {
      name: 'jeff',
      roles: %w(developers),
      ensure: :present,
      version: :v3
    }.merge(resource_override)
  end

  let(:resource) { type.new(resource_hash) }
  let(:provider) { described_class.new(resource) }

  before :each do
    allow(described_class.api).to receive(:snmp_users)
      .and_return(fixture(:api_snmp_users))
  end

  describe 'class methods' do
    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }
      it 'each provider has ensure=present' do
        subject.each { |p| expect(p.ensure).to eq(:present) }
      end
      it { expect(subject.size).to eq(3) }
    end
  end

  describe '#flush' do
    let(:provider) do
      provider = described_class.new(resource_hash)
      provider.resource = resource
      provider
    end

    before :each do
      allow(provider.api).to receive(:snmp_user_set)
        .and_return(password: 'foobar')
    end

    context 'after create' do
      subject do
        provider.create
        provider.flush
      end

      it 'calls snmp_user_set' do
        expect(provider.api).to receive(:snmp_user_set)
          .and_return(password: 'foobar')
        subject
      end

      context 'when the resource name contains a colon' do
        let(:resource_override) do
          { name: 'jeff:v3' }
        end

        it 'splits the name on colon' do
          expect(provider.api).to receive(:snmp_user_set)
            .with(include(name: 'jeff', version: :v3))
            .and_return(password: 'foobar')
          subject
        end
      end
    end

    context 'after destroy' do
      subject do
        provider.destroy
        provider.flush
      end

      let(:expected) do
        { name: 'jeff', roles: %w(developers), version: :v3 }
      end

      context 'when the resource name matches the title' do
        it 'calls snmp_user_destroy' do
          expect(provider.api).to receive(:snmp_user_destroy)
            .with(include(expected)).and_return({})
          subject
        end
      end

      context 'when the resource name contains a colon' do
        let(:resource_override) do
          { name: 'jeff:v3' }
        end

        it 'splits the name on colon' do
          expect(provider.api).to receive(:snmp_user_destroy)
            .with(include(expected))
            .and_return({})
          subject
        end
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

    it 'sets @property_flush with name: "jeff"' do
      subject
      expect(provider.instance_variable_get(:@property_flush))
        .to include(name: 'jeff')
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

  it_behaves_like 'provider exists?'

  describe '.prefetch(resources)' do
    let(:matching_resource) do
      {
        name: 'jeff',
        version: :v3,
        ensure: :present,
        auth: 'sha',
        privacy: 'aes128',
        roles: %w(developers)
      }
    end

    let(:resources) do
      {
        'jeff:v3'   => type.new(matching_resource),
        'emanon:v3' => type.new(matching_resource.merge(name: 'emanon'))
      }
    end

    subject { described_class.prefetch(resources) }

    it 'updates the provider of managed resources with instances' do
      orig_provider_obj_id = resources['jeff:v3'].provider.object_id
      subject
      new_provider_obj_id = resources['jeff:v3'].provider.object_id
      expect(orig_provider_obj_id).to_not eq(new_provider_obj_id)
    end

    it 'preserves the provider for managed resources with no instances' do
      orig_provider_obj_id = resources['emanon:v3'].provider.object_id
      subject
      new_provider_obj_id = resources['emanon:v3'].provider.object_id
      expect(orig_provider_obj_id).to eq(new_provider_obj_id)
    end
  end
end
