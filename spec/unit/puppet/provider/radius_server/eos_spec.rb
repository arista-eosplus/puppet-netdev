# encoding: utf-8

require 'spec_helper'

describe Puppet::Type.type(:radius_server).provider(:eos) do
  let(:radius) { PuppetX::Eos::Radius.new(PuppetX::Eos::Eapi.new) }

  let(:type) { Puppet::Type.type(:radius_server) }

  # Allow text cases to override resource attributes
  let :resource_override do
    {}
  end

  let :resource_hash do
    {
      ensure: :present,
      name: '127.0.0.1/1812/1813',
      hostname: '127.0.0.1',
      auth_port: 1812,
      acct_port: 1813,
      timeout: 10,
      retransmit_count: 3,
      key: '1513090F557878',
      key_format: 7
    }.merge(resource_override)
  end

  let(:resource) { type.new(resource_hash) }
  let(:provider) { described_class.new(resource) }

  it_behaves_like 'provider exists?'

  describe 'class methods' do
    before :each do
      allow(described_class.eapi).to receive(:Radius).and_return(radius)
    end

    describe '.instances' do
      before :each do
        allow(radius).to receive(:servers)
          .and_return(fixture(:eapi_radius_servers))
      end

      subject { described_class.instances }

      it { is_expected.to be_an Array }
      it { expect(subject.size).to eq(6) }
      it 'sets the name parameter as <hostname>/<auth_port>/<acct_port>' do
        subject.each { |i| expect(i.name).to match %r{^.*?/\d+/\d+$} }
      end
    end
  end

  describe 'instance methods' do
    before :each do
      allow(provider.eapi).to receive(:Radius).and_return(radius)
    end

    describe '#flush' do
      context 'after create' do
        subject do
          provider.create
          provider.flush
        end

        it 'calls PuppetX::Eos::Radius#update_server' do
          expect(radius).to receive(:update_server)
            .with(include(hostname: '127.0.0.1'))
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

        it 'calls PuppetX::Eos::Radius#remove_server' do
          expect(radius).to receive(:remove_server)
            .with(include(hostname: '127.0.0.1'))
            .and_return(true)
          subject
        end
      end
    end
  end
end
