# encoding: utf-8

require 'spec_helper'

describe Puppet::Type.type(:snmp_community).provider(:eos) do
  let(:type) { Puppet::Type.type(:snmp_community) }

  let :resource do
    resource_hash = {
      name: 'public',
      group: 'ro',
      acl: 'Public Community'
    }
    type.new(resource_hash)
  end

  let(:provider) { resource.provider }

  before :each do
    allow(described_class.api).to receive(:snmp_communities)
      .and_return(fixture(:api_snmp_communities))
  end

  describe 'class methods' do
    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }
    end
  end

  describe '#group=(value)' do
  end

  describe '#acl=(value)' do
  end
end
