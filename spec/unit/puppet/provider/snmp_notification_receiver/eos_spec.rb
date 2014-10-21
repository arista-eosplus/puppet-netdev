# encoding: utf-8

require 'spec_helper'

describe Puppet::Type.type(:snmp_notification_receiver).provider(:eos) do
  let(:type) { Puppet::Type.type(:snmp_notification_receiver) }

  # Allow text cases to override resource attributes
  let :resource_override do
    {}
  end

  let :resource_hash do
    {
      ensure: :present,
      name: '127.0.0.1',
      type: :traps,
      version: :v3,
      username: 'snmpuser',
      security: :noauth
    }.merge(resource_override)
  end

  let(:resource) { type.new(resource_hash) }
  let(:provider) { described_class.new(resource) }

  it_behaves_like 'provider exists?'

  describe 'class methods' do
    describe '.instances' do
      subject { described_class.instances }

      context 'when there are no duplicate hosts' do
        before :each do
          allow(described_class.api).to receive(:snmp_notification_receivers)
            .and_return(fixture(:api_snmp_notification_receivers))
        end

        it_behaves_like 'provider instances', size: 4
      end

      context 'when there are duplicate host entries' do
        before :each do
          allow(described_class.api).to receive(:snmp_notification_receivers)
            .and_return(fixture(:api_snmp_notification_receivers_duplicates))
        end

        it_behaves_like 'provider instances', size: 5
        it 'does not declare duplicate resources by name' do
          uniq_size = subject.uniq(&:name).size
          expect(subject.size).to eq(uniq_size)
        end
      end

      context 'when there are more duplicate host entries' do
        before :each do
          fixed_data = fixture(:api_snmp_notification_receivers_more_duplicates)
          allow(described_class.api).to receive(:snmp_notification_receivers)
            .and_return(fixed_data)
        end

        it_behaves_like 'provider instances', size: 8
      end
    end

    describe '.prefetch' do
      before :each do
        fixed_data = fixture(:api_snmp_notification_receivers_more_duplicates)
        allow(described_class.api).to receive(:snmp_notification_receivers)
          .and_return(fixed_data)
      end

      # "127.0.0.1:public:162:v3:traps:noauth"
      let(:matching_resource) do
        {
          name: '127.0.0.1',
          username: 'public',
          port: 162,
          version: :v3,
          type: :traps,
          security: :noauth
        }
      end
      let(:resources) do
        {
          '127.0.0.1' => type.new(matching_resource),
          '127.0.0.2' => type.new(matching_resource.merge(name: '127.0.0.2'))
        }
      end
      subject { described_class.prefetch(resources) }

      it 'updates the provider of managed resources with instances' do
        orig_provider_obj_id = resources['127.0.0.1'].provider.object_id
        subject
        new_provider_obj_id = resources['127.0.0.1'].provider.object_id
        expect(orig_provider_obj_id).to_not eq(new_provider_obj_id)
      end

      it 'preserves the provider for managed resources with no instances' do
        orig_provider_obj_id = resources['127.0.0.2'].provider.object_id
        subject
        new_provider_obj_id = resources['127.0.0.2'].provider.object_id
        expect(orig_provider_obj_id).to eq(new_provider_obj_id)
      end
    end
  end

  describe '#create' do
    describe '@property_flush' do
      subject do
        provider.create
        provider.instance_variable_get(:@property_flush)
      end
      it { is_expected.to include(ensure: :present) }
      it { is_expected.to include(port: 162) }
      it { is_expected.to include(version: :v3) }
      it { is_expected.to include(username: 'snmpuser') }
      it { is_expected.to include(type: :traps) }
      it { is_expected.to include(name: '127.0.0.1') }
      it { is_expected.to include(security: :noauth) }
      it { is_expected.to_not include(:community) }
    end
  end

  describe '#flush' do
    context 'when creating' do
      before :each do
        allow(provider.api).to receive(:snmp_notification_receiver_set)
          .and_return(true)
      end
      subject do
        provider.create
        provider.flush
      end

      let(:name) { '127.0.0.1:snmpuser:162' }

      it 'calls snmp_notification_receiver_set' do
        expect(provider.api).to receive(:snmp_notification_receiver_set)
          .and_return(true)
        subject
      end
      it 'adds the default port of 162' do
        expect(provider.api).to receive(:snmp_notification_receiver_set)
          .with(resource_hash.merge(port: 162)).and_return(true)
        subject
      end
      describe 'the resulting property_hash' do
        subject do
          provider.create
          provider.flush
          provider.instance_variable_get(:@property_hash)
        end

        it { is_expected.to include(name: name) }
        it { is_expected.to include(ensure: :present) }
        it { is_expected.to include(username: 'snmpuser') }
        it { is_expected.to include(port: 162) }
        it { is_expected.to include(version: :v3) }
        it { is_expected.to include(type: :traps) }
        it { is_expected.to include(security: :noauth) }
      end
    end

    context 'when destroying' do
      let(:resource_override) { { ensure: :absent } }
      before :each do
        allow(provider.api).to receive(:snmp_notification_receiver_remove)
          .and_return(true)
      end
      subject do
        provider.destroy
        provider.flush
      end

      let(:name) { '127.0.0.1:snmpuser:162' }

      it 'calls snmp_notification_receiver_remove' do
        expect(provider.api).to receive(:snmp_notification_receiver_remove)
          .and_return(true)
        subject
      end
      describe 'the resulting property_hash' do
        subject do
          provider.destroy
          provider.flush
          provider.instance_variable_get(:@property_hash)
        end

        it { is_expected.to include(name: name) }
        it { is_expected.to include(ensure: :absent) }
        it { is_expected.to include(username: 'snmpuser') }
        it { is_expected.to include(port: 162) }
        it { is_expected.to include(version: :v3) }
        it { is_expected.to include(type: :traps) }
        it { is_expected.to include(security: :noauth) }
      end
    end
  end
end
