# encoding: utf-8

require 'spec_helper'

describe Puppet::Type.type(:tacacs_server_group).provider(:eos) do
  let(:api) { PuppetX::Eos::Tacacs.new(PuppetX::Eos::Eapi.new) }
  let(:type) { Puppet::Type.type(:tacacs_server_group) }

  # Allow text cases to override resource attributes
  let :resource_override do
    {}
  end

  let :resource_hash do
    {
      ensure: :present,
      name: 'TAC-SV9',
      servers: ['10.11.12.13/1024', '10.11.12.13/49']
    }.merge(resource_override)
  end

  let(:resource) { type.new(resource_hash) }
  let(:provider) { described_class.new(resource) }

  it_behaves_like 'provider exists?'

  describe 'class methods' do
    before :each do
      allow(described_class.eapi).to receive(:Tacacs).and_return(api)
    end

    describe '.instances' do
      before :each do
        allow(api).to receive(:server_groups)
          .and_return(fixture(:eapi_tacacs_server_groups))
      end

      subject { described_class.instances }

      it { is_expected.to be_an Array }
      include_examples 'attribute', size: 3
    end
  end

  describe 'instance methods' do
    before :each do
      allow(provider.eapi).to receive(:Tacacs).and_return(api)
    end

    describe '#flush' do
      context 'after create' do
        subject do
          provider.create
          provider.flush
        end

        it 'calls PuppetX::Eos::Tacacs#update_server_group' do
          expect(api).to receive(:update_server_group)
            .with(include(name: 'TAC-SV9'))
            .and_return(true)
          subject
        end
      end

      context 'after destroy' do
        let :resource_override do
          { ensure: :absent }
        end

        subject do
          provider.destroy
          provider.flush
        end

        it 'calls PuppetX::Eos::Tacacs#remove_server_group' do
          expect(api).to receive(:remove_server_group)
            .with(include(name: 'TAC-SV9'))
            .and_return(true)
          subject
        end
      end

      context 'after updating servers' do
        subject do
          provider.create
          provider.servers=[]
          provider.flush
        end

        it 'calls PuppetX::Eos::Tacacs#update_server_group' do
          expect(api).to receive(:update_server_group)
            .with(include(name: 'TAC-SV9', servers: []))
            .and_return(true)
          subject
        end
      end
    end
  end
end
