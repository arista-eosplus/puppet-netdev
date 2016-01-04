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

describe Puppet::Type.type(:port_channel).provider(:eos) do
  # Puppet RAL memoized methods
  let(:resource) do
    resource_hash = {
      ensure: :present,
      name: 'Port-Channel1',
      mode: :active,
      interfaces: %w(Ethernet1 Ethernet2),
      minimum_links: 2,
      provider: described_class.name
    }
    Puppet::Type.type(:port_channel).new(resource_hash)
  end

  let(:provider) { resource.provider }

  let(:api) { double('interfaces') }

  def portchannels
    portchannels = Fixtures[:portchannels]
    return portchannels if portchannels
    fixture('portchannels', dir: File.dirname(__FILE__))
  end

  before :each do
    allow(described_class.node).to receive(:api).with('interfaces')
      .and_return(api)
    allow(provider.node).to receive(:api).with('interfaces').and_return(api)
  end

  context 'class methods' do
    before { allow(api).to receive(:getall).and_return(portchannels) }

    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }

      it 'has one entry' do
        expect(subject.size).to eq 1
      end

      it 'has an instance for Port-Channel1' do
        instance = subject.find { |p| p.name == 'Port-Channel1' }
        expect(instance).to be_a described_class
      end

      context "port_channel { 'Port-Channel1': }" do
        subject { described_class.instances.find { |p| p.name == 'Port-Channel1' } }

        include_examples 'provider resource methods',
                         ensure: :present,
                         name: 'Port-Channel1',
                         mode: :disabled,
                         interfaces: %w(Ethernet1 Ethernet2),
                         minimum_links: '2'
      end
    end

    describe '.prefetch' do
      let :resources do
        {
          'Port-Channel1' => Puppet::Type.type(:port_channel)
            .new(name: 'Port-Channel1'),
          'Port-Channel5' => Puppet::Type.type(:port_channel)
            .new(name: 'Port-Channel5')
        }
      end

      subject { described_class.prefetch(resources) }

      it 'resource providers are absent prior to calling .prefetch' do
        resources.values.each do |rsrc|
          expect(rsrc.provider.mode).to eq(:absent)
          expect(rsrc.provider.interfaces).to eq(:absent)
          expect(rsrc.provider.minimum_links).to eq(:absent)
        end
      end

      it 'sets the provider instance of the managed resource' do
        subject
        expect(resources['Port-Channel1'].provider.name).to eq 'Port-Channel1'
        expect(resources['Port-Channel1'].provider.exists?).to be_truthy
        expect(resources['Port-Channel1'].provider.mode).to eq :disabled
        expect(resources['Port-Channel1'].provider.interfaces).to eq %w(Ethernet1 Ethernet2)
        expect(resources['Port-Channel1'].provider.minimum_links).to eq '2'
      end

      it 'does not set the provider instance of the unmanaged resource' do
        subject
        expect(resources['Port-Channel5'].provider.name).to eq('Port-Channel5')
        expect(resources['Port-Channel5'].provider.exists?).to be_falsey
        expect(resources['Port-Channel5'].provider.mode).to eq :absent
        expect(resources['Port-Channel5'].provider.interfaces).to eq :absent
        expect(resources['Port-Channel5'].provider.minimum_links).to eq :absent
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
          allow(api).to receive(:getall).and_return(portchannels)
          described_class.instances.first
        end
        it { is_expected.to be_truthy }
      end
    end

    describe '#create' do
      let(:name) { resource[:name] }

      before do
        expect(api).to receive(:create).with(name)
        allow(api).to receive_messages(
          set_lacp_mode: true,
          set_members: true,
          set_minimum_links: true
        )
      end

      it 'sets ensure to :present' do
        provider.create
        expect(provider.ensure).to eq(:present)
      end

      it 'sets mode to the resource value' do
        provider.create
        expect(provider.mode).to eq resource[:mode]
      end

      it 'sets interfaces to the resource value' do
        provider.create
        expect(provider.interfaces).to eq resource[:interfaces]
      end

      it 'sets minimum_links to the resource value' do
        provider.create
        expect(provider.minimum_links).to eq resource[:minimum_links]
      end
    end

    describe '#destroy' do
      it 'sets ensure to :absent' do
        expect(api).to receive(:delete).with(resource[:name])
        provider.destroy
        expect(provider.ensure).to eq(:absent)
      end
    end

    describe '#mode=(value)' do
      let(:name) { resource[:name] }

      %w(:active :passive :disabled).each do |value|
        it 'updates mode on the provider' do
          val = value == 'disabled' ? 'on' : value
          expect(api).to receive(:set_lacp_mode).with(name, val)
          provider.mode = value
          expect(provider.mode).to eq value
        end
      end
    end

    describe '#interfaces=(val)' do
      let(:value) { %w(Ethernet1 Ethernet2 Ethernet3) }
      it 'updates interfaces on the provider' do
        expect(api).to receive(:set_members) .with(resource[:name], value)
        provider.interfaces = value
        expect(provider.interfaces).to eq value
      end
    end

    describe '#minimum_links=(val)' do
      it 'updates minimum_links on the provider' do
        expect(api).to receive(:set_minimum_links).with(resource[:name],
                                                        value: 4)
        provider.minimum_links = 4
        expect(provider.minimum_links).to eq 4
      end
    end
  end
end
