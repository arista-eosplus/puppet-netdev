# encoding: utf-8

require 'spec_helper'

describe Puppet::Type.type(:tacacs_global).provider(:eos) do
  let(:api) { PuppetX::Eos::Tacacs.new(PuppetX::Eos::Eapi.new) }

  let(:type) { Puppet::Type.type(:tacacs_global) }

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
      timeout: 30
    }.merge(resource_override)
  end

  let(:resource) { type.new(resource_hash) }
  let(:provider) { described_class.new(resource) }

  describe 'class methods' do
    before :each do
      allow(described_class.eapi).to receive(:Tacacs).and_return(api)
    end

    describe '.instances' do
      before :each do
        allow(api).to receive(:getall)
          .and_return(fixture(:eapi_tacacs_getall_configured))
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
        it 'timeout is 7' do
          expect(subject.timeout).to eq 7
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
      allow(provider.eapi).to receive(:Tacacs).and_return(api)
    end

    describe '#enable=false' do
      it 'raises ArgumentError because EOS cannot disable the resource' do
        expect { provider.enable = false }
          .to raise_error ArgumentError, /cannot be disabled/
      end
    end

    describe '#retransmit_count=5' do
      it 'raises NotImplementedError because retransmit cannot be configured' do
        expect { provider.retransmit_count = 5 }
          .to raise_error NotImplementedError, /cannot be configured/
      end
    end

    describe '#flush' do
      before :each do
        allow(api).to receive(:set_global_key).and_return(true)
        allow(api).to receive(:set_timeout).and_return(true)
      end

      context 'after updating the key' do
        subject do
          provider.key = 'updatedkey'
          provider.key_format = 5
          provider.flush
        end

        it 'calls Tacacs#set_global_key to configure the key' do
          expect(api).to receive(:set_global_key)
            .with(include(key: 'updatedkey'))
          subject
        end
        it 'does not update the timeout' do
          expect(api).not_to receive(:set_timeout)
          subject
        end
      end

      context 'after updating the timeout' do
        subject do
          provider.timeout = 120
          provider.flush
        end

        it 'does not update the key' do
          expect(api).not_to receive(:set_global_key)
          subject
        end
        it 'calls Tacacs#set_timeout to configure the timeout' do
          expect(api).to receive(:set_timeout)
            .with(include(timeout: 120))
          subject
        end
      end
    end
  end
end
