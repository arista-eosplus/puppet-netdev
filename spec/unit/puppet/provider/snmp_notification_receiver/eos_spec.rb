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
      security: :noauth,
      community: 'private',
      vrf: 'management',
      source_interface: 'Management1'
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
        it 'does not declare duplicate resources by name' do
          uniq_size = subject.uniq(&:name).size
          expect(subject.size).to eq(uniq_size)
        end
      end
    end
  end
end
