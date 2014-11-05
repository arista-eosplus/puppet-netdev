# encoding: utf-8

require 'spec_helper'

describe Puppet::Type.type(:radius_global).provider(:eos) do
  let(:radius) { PuppetX::Eos::Radius.new(PuppetX::Eos::Eapi.new) }

  let(:type) { Puppet::Type.type(:radius_global) }

  # Allow text cases to override resource attributes
  let :resource_override do
    {}
  end

  let :resource_hash do
    {
      name: 'settings',
      enable: true,
      key: '070E234F1F5B4A',
      key_format: 7,
      retransmit_count: 5,
      timeout: 30
    }.merge(resource_override)
  end

  let(:resource) { type.new(resource_hash) }
  let(:provider) { described_class.new(resource) }

  describe 'class methods' do
    before :each do
      allow(described_class.eapi).to receive(:Radius).and_return(radius)
    end

    describe '.instances' do
      before :each do
        allow(radius).to receive(:getall)
          .and_return(fixture(:eapi_radius_getall_configured))
      end

      subject { described_class.instances }

      it { is_expected.to be_an Array }
      it { expect(subject.size).to eq(1) }

      describe 'the single returned instance' do
        subject { described_class.instances.first }

        it { is_expected.to be_a described_class }
        it 'has the name "settings"' do
          expect(subject.name).to eq 'settings'
        end
        it 'enable is true' do
          expect(subject.enable).to eq true
        end
        it 'key is 070E234F1F5B4A' do
          expect(subject.key).to eq '070E234F1F5B4A'
        end
        it 'key_format is 7 (hashed)' do
          expect(subject.key_format).to eq 7
        end
        it 'timeout is 50' do
          expect(subject.timeout).to eq 50
        end
        it 'retransmit_count is 5' do
          expect(subject.retransmit_count).to eq 5
        end
      end
    end
  end

  describe 'instance methods' do
    let(:provider) do
      provider = described_class.new(resource_hash)
      provider.resource = resource
      provider
    end

    before :each do
      allow(provider.eapi).to receive(:Radius).and_return(radius)
    end

    describe '#enable=false' do
      it 'raises ArgumentError because EOS cannot disable the provider' do
        expect { provider.enable = false }
          .to raise_error ArgumentError, /cannot be disabled/
      end
    end

    describe '#flush' do
      before :each do
        allow(radius).to receive(:set_global_key).and_return(true)
        allow(radius).to receive(:set_timeout).and_return(true)
        allow(radius).to receive(:set_retransmit_count).and_return(true)
      end

      context 'after updating the key' do
        subject do
          provider.key = 'updatedkey'
          provider.key_format = 0
          provider.flush
        end

        it 'calls Radius#set_global_key to configure the key' do
          expect(radius).to receive(:set_global_key)
            .with(include(key: 'updatedkey'))
          subject
        end
        it 'does not update the timeout' do
          expect(radius).not_to receive(:set_timeout)
          subject
        end
        it 'does not update the retransmit count' do
          expect(radius).not_to receive(:set_retransmit_count)
          subject
        end
      end

      context 'after updating the timeout' do
        subject do
          provider.timeout = 120
          provider.flush
        end

        it 'does not update the key' do
          expect(radius).not_to receive(:set_global_key)
          subject
        end
        it 'calls Radius#set_timeout to configure the timeout' do
          expect(radius).to receive(:set_timeout)
            .with(include(timeout: 120))
          subject
        end
        it 'does not update the retransmit count' do
          expect(radius).not_to receive(:set_retransmit_count)
          subject
        end
      end

      context 'after updating the retransmit_count' do

        subject do
          provider.retransmit_count = 7
          provider.flush
        end

        it 'does not update the key' do
          expect(radius).not_to receive(:set_global_key)
          subject
        end
        it 'does not update the timeout' do
          expect(radius).not_to receive(:set_timeout)
          subject
        end
        it 'calls Radius#set_retransmit_count to configure the retransmit' do
          expect(radius).to receive(:set_retransmit_count)
            .with(include(retransmit_count: 7))
          subject
        end
      end
    end
  end
end
