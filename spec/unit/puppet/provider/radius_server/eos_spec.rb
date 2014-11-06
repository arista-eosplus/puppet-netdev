# encoding: utf-8

require 'spec_helper'

describe Puppet::Type.type(:radius_server).provider(:eos) do
  let(:radius) { PuppetX::Eos::Radius.new(PuppetX::Eos::Eapi.new) }

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
end
