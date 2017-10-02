# encoding: utf-8
#
# Copyright (c) 2014, Arista Networks, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#   Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
#
#   Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
#
#   Neither the name of Arista Networks nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL ARISTA NETWORKS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require 'spec_helper'
include FixtureHelpers

describe Puppet::Type.type(:snmp_user).provider(:eos) do
  let(:type) { Puppet::Type.type(:snmp_user) }

  # Allow text cases to override resource attributes
  let :resource_override do
    {}
  end

  let :resource_hash do
    {
      name: 'jeff',
      roles: %w(developers),
      ensure: :present,
      version: :v3
    }.merge(resource_override)
  end

  let(:resource) { type.new(resource_hash) }
  let(:provider) { described_class.new(resource) }

  let(:api) { double('snmp') }

  def snmp
    snmp = Fixtures[:snmp]
    return snmp if snmp
    fixture('api_snmp_users')
  end

  before :each do
    allow(described_class.node).to receive(:api).with('snmp').and_return(api)
    allow(provider.node).to receive(:api).with('snmp').and_return(api)
  end

  context 'class methods' do
    before { allow(api).to receive(:get).and_return(snmp) }

    describe '.instances' do
      subject { described_class.instances }

      it 'has a known property_hash' do
        expect(described_class.instances[0].instance_variable_get("@property_hash")).to eq( {
          :name=>"jeff:v3",
          :ensure=>:present,
          :auth => :sha,
          :engine_id=>"f5717f00420008177800",
          :privacy => :aes128,
          :roles=>["developers"],
          :version=>:v3,
        } )
      end
      it { is_expected.to be_an Array }
      it 'each provider has ensure=present' do
        subject.each { |p| expect(p.ensure).to eq(:present) }
      end
      it { expect(subject.size).to eq(3) }
    end
  end

  describe '#flush' do
    let(:provider) do
      provider = described_class.new(resource_hash)
      provider.resource = resource
      provider
    end

    before :each do
      allow(api).to receive(:set_user)
        .and_return(password: 'foobar')
    end

    context 'after create' do
      subject do
        provider.create
        provider.flush
      end

      it 'calls set_user' do
        expect(api).to receive(:set_user)
          .and_return(password: 'foobar')
        subject
      end

      context 'when the resource name contains a colon' do
        let(:resource_override) do
          { name: 'jeff:v3' }
        end

        it 'splits the name on colon' do
          expect(api).to receive(:set_user)
            .with(include(name: 'jeff', version: :v3))
            .and_return(password: 'foobar')
          subject
        end
      end
    end

    context 'after destroy' do
      subject do
        provider.destroy
        provider.flush
      end

      let(:expected) do
          { name: 'jeff', roles: %w(developers), version: :v3, ensure: :absent }
      end

      context 'when the resource name matches the title' do
        it 'calls set_user to destroy' do
          expect(api).to receive(:set_user)
            .with(include(expected)).and_return({})
          subject
        end
      end

      context 'when the resource name contains a colon' do
        let(:resource_override) do
          { name: 'jeff:v3' }
        end

        it 'splits the name on colon' do
          expect(api).to receive(:set_user)
            .with(include(expected))
            .and_return({})
          subject
        end
      end
    end
  end

  describe '#create' do
    subject { provider.create }

    it 'sets @property_flush with ensure: present' do
      subject
      expect(provider.instance_variable_get(:@property_flush))
        .to include(ensure: :present)
    end

    it 'sets @property_flush with name: "jeff"' do
      subject
      expect(provider.instance_variable_get(:@property_flush))
        .to include(name: 'jeff')
    end
  end

  describe '#destroy' do
    subject { provider.destroy }

    it 'sets @property_flush with ensure: absent' do
      subject
      expect(provider.instance_variable_get(:@property_flush))
        .to include(ensure: :absent)
    end
  end

  it_behaves_like 'provider exists?'

  describe '.prefetch(resources)' do
    before { allow(api).to receive(:get).and_return(snmp) }

    let(:matching_resource) do
      {
        name: 'jeff',
        version: :v3,
        ensure: :present,
        auth: 'sha',
        privacy: 'aes128',
        roles: %w(developers)
      }
    end

    let(:resources) do
      {
        'jeff:v3'   => type.new(matching_resource),
        'emanon:v3' => type.new(matching_resource.merge(name: 'emanon'))
      }
    end

    subject { described_class.prefetch(resources) }

    it 'updates the provider of managed resources with instances' do
      orig_provider_obj_id = resources['jeff:v3'].provider.object_id
      subject
      new_provider_obj_id = resources['jeff:v3'].provider.object_id
      expect(orig_provider_obj_id).to_not eq(new_provider_obj_id)
    end

    it 'preserves the provider for managed resources with no instances' do
      orig_provider_obj_id = resources['emanon:v3'].provider.object_id
      subject
      new_provider_obj_id = resources['emanon:v3'].provider.object_id
      expect(orig_provider_obj_id).to eq(new_provider_obj_id)
    end
  end
end
