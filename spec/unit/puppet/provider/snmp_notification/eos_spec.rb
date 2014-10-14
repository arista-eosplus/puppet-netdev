# encoding: utf-8

require 'spec_helper'

describe Puppet::Type.type(:snmp_notification).provider(:eos) do
  let(:type) { Puppet::Type.type(:snmp_notification) }

  # Allow text cases to override resource attributes
  let :resource_override do
    {}
  end

  let :resource_hash do
    {
      name: 'snmp link-down',
      enable: :true
    }.merge(resource_override)
  end

  let(:resource) { type.new(resource_hash) }
  let(:provider) { described_class.new(resource) }

  before :each do
    allow(described_class.api).to receive(:snmp_notifications)
      .and_return(fixture(:api_snmp_notifications))
  end

  describe 'class methods' do
    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }
      it 'returns 23 instances' do
        expect(subject.size).to eq(23)
      end
    end

    describe '.flush' do
      context 'after enable = :true' do
        subject do
          provider.enable = :true
          provider.flush
        end

        it 'calls snmp_notification_set' do
          expect(provider.api).to receive(:snmp_notification_set)
            .with(resource_hash)
          subject
        end

        context 'stubbed REST API' do
          before :each do
            allow(provider.api).to receive(:eapi_action)
              .with(Array, 'set snmp trap')
              .and_return([{}, {}, {}])
          end

          it { is_expected.to eq(resource_hash) }
        end
      end
    end
  end
end
