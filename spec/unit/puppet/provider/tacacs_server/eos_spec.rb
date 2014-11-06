# encoding: utf-8

require 'spec_helper'

describe Puppet::Type.type(:tacacs_server).provider(:eos) do
  let(:eapi) { PuppetX::Eos::Tacacs.new(PuppetX::Eos::Eapi.new) }

  let(:type) { Puppet::Type.type(:tacacs_server) }

  # Allow text cases to override resource attributes
  let :resource_override do
    {}
  end

  let :resource_hash do
    {
      ensure: :present,
      name: '127.0.0.1/49',
      hostname: '127.0.0.1',
      port: 49,
      timeout: 10,
      key: '1513090F557878',
      key_format: 7
    }.merge(resource_override)
  end

  let(:resource) { type.new(resource_hash) }
  let(:provider) { described_class.new(resource) }

  it_behaves_like 'provider exists?'

  describe 'class methods' do
    before :each do
      allow(described_class.eapi).to receive(:Tacacs).and_return(eapi)
    end

    describe '.instances' do
      before :each do
        allow(eapi).to receive(:servers)
          .and_return(fixture(:eapi_tacacs_servers))
      end

      subject { described_class.instances }

      it { is_expected.to be_an Array }
      it 'size is 4' do
        expect(subject.size).to eq(4)
      end
      it 'sets the name parameter as <hostname>/<auth_port>/<acct_port>' do
        subject.each { |i| expect(i.name).to match /^.*?\/\d+$/ }
      end
    end
  end
end
