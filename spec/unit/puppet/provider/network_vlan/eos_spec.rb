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
#
require 'spec_helper'

include FixtureHelpers

describe Puppet::Type.type(:network_vlan).provider(:eos) do

  # Puppet RAL memoized methods
  let(:resource) do
    resource_hash = {
      ensure: :present,
      name: '1234',
      vlan_name: 'VLAN1234',
      shutdown: :false,
      provider: described_class.name
    }
    Puppet::Type.type(:network_vlan).new(resource_hash)
  end

  let(:provider) { resource.provider }

  let(:api) { double('vlans') }

  def vlans
    vlans = Fixtures[:vlans]
    return vlans if vlans
    fixture('vlans', dir: File.dirname(__FILE__))
  end

  before :each do
    allow(described_class.node).to receive(:api).with('vlans').and_return(api)
    allow(provider.node).to receive(:api).with('vlans').and_return(api)
  end

  context 'class methods' do

    before { allow(api).to receive(:getall).and_return(vlans) }

    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }

      it 'has only one entry' do
        expect(subject.size).to eq 1
      end

      it 'has an instance for VLAN 1' do
        instance = subject.find { |p| p.name == '1' }
        expect(instance).to be_a described_class
      end

      context 'eos_vlan { 1: }' do
        subject { described_class.instances.find { |p| p.name == '1' } }

        include_examples 'provider resource methods',
                         ensure: :present,
                         name: '1',
                         vlan_name: 'default',
                         shutdown: :false,
                         exists?: true
      end
    end

    describe '.prefetch' do
      let :resources do
        {
          '1' => Puppet::Type.type(:network_vlan).new(id: '1'),
          '2' => Puppet::Type.type(:network_vlan).new(id: '2'),
        }
      end

      subject { described_class.prefetch(resources) }

      it 'resource providers are absent prior to calling .prefetch' do
        resources.values.each do |rsrc|
          expect(rsrc.provider.vlan_name).to eq(:absent)
          expect(rsrc.provider.shutdown).to eq(:absent)
        end
      end

      it 'sets the provider instance of the managed resource' do
        subject
        expect(resources['1'].provider.id).to eq(1)
        expect(resources['1'].provider.vlan_name).to eq('default')
        expect(resources['1'].provider.shutdown).to eq(:false)
        expect(resources['1'].provider.exists?).to be_truthy
      end

      it 'does not set the provider instance of the unmanaged resource' do
        subject
        expect(resources['2'].provider.id).to eq(:absent)
        expect(resources['2'].provider.vlan_name).to eq(:absent)
        expect(resources['2'].provider.shutdown).to eq(:absent)
        expect(resources['2'].provider.exists?).to be_falsey
      end
    end
  end

  context 'resource (instance) methods' do

    describe '#exists?' do
      subject { provider.exists? }

      context 'when the resource does not exist on the system' do
        it { is_expected.to be_falsey }
      end

      context 'when the resource exists on the system' do
        let(:provider) do
          allow(api).to receive(:getall).and_return(vlans)
          described_class.instances.first
        end
        it { is_expected.to be_truthy }
      end
    end

    describe '#create' do
      let(:vid) { resource[:name] }

      before do
        allow(api).to receive_messages(
          :set_state => true,
          :set_name => true
        )
        expect(api).to receive(:create).with(resource[:name])
      end

      it 'sets ensure to :present' do
        provider.create
        expect(provider.ensure).to eq(:present)
      end

      it 'sets shutdown to the resource value' do
        provider.create
        expect(provider.shutdown).to be_truthy
      end

      it 'sets vlan_name to the resource value' do
        provider.create
        expect(provider.vlan_name).to eq(provider.resource[:vlan_name])
      end
    end

    describe '#destroy' do
      it 'sets ensure to :absent' do
        expect(api).to receive(:delete).with(resource[:name])
        provider.destroy
        expect(provider.ensure).to eq(:absent)
      end
    end

    describe '#vlan_name=(value)' do
      it 'updates vlan_name in the provider' do
        expect(api).to receive(:set_name).with(resource[:name], value: 'foo')
        provider.vlan_name = 'foo'
        expect(provider.vlan_name).to eq('foo')
      end
    end

    describe '#shutdown=(value)' do
      let(:vid) { resource[:name] }

      it 'updates shutdown with value :true' do
        expect(api).to receive(:set_state).with(vid, value: 'suspend')
        provider.shutdown = :true
        expect(provider.shutdown).to eq(:true)
      end

      it 'updates shutdown with value :false' do
        expect(api).to receive(:set_state).with(vid, value: 'active')
        provider.shutdown = :false
        expect(provider.shutdown).to eq(:false)
      end
    end
  end
end
