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

describe Puppet::Type.type(:network_interface).provider(:eos) do
  # Puppet RAL memoized methods
  let(:resource) do
    resource_hash = {
      name: 'Ethernet1',
      description: 'test interface',
      enable: :true,
      speed: '100g',
      duplex: :full,
      provider: described_class.name
    }
    Puppet::Type.type(:network_interface).new(resource_hash)
  end

  let(:provider) { resource.provider }

  let(:api) { double('interfaces') }

  def interfaces
    interfaces = Fixtures[:interfaces]
    return interfaces if interfaces
    fixture('interfaces', dir: File.dirname(__FILE__))
  end

  before :each do
    allow(described_class.node).to receive(:api).with('interfaces')
                                                .and_return(api)
    allow(provider.node).to receive(:api).with('interfaces').and_return(api)
  end

  context 'class methods' do
    before { allow(api).to receive(:getall).and_return(interfaces) }

    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }

      it 'has one entry' do
        expect(subject.size).to eq(1)
      end

      it 'has an instance for interface Ethernet1' do
        instance = subject.find { |p| p.name == 'Ethernet1' }
        expect(instance).to be_a described_class
      end

      context 'network_interface { Ethernet1: }' do
        subject { described_class.instances.find { |p| p.name == 'Ethernet1' } }

        include_examples 'provider resource methods',
                         name: 'Ethernet1',
                         description: 'test interface',
                         enable: :true,
                         speed: '100g',
                         duplex: :full
      end
    end

    describe '.prefetch' do
      let :resources do
        {
          'Ethernet1' => Puppet::Type.type(:network_interface)
                                     .new(name: 'Ethernet1'),
          'Ethernet2' => Puppet::Type.type(:network_interface)
                                     .new(name: 'Ethernet2')
        }
      end
      subject { described_class.prefetch(resources) }

      it 'resource providers are absent prior to calling .prefetch' do
        resources.values.each do |rsrc|
          expect(rsrc.provider.description).to eq(:absent)
          expect(rsrc.provider.enable).to eq(:absent)
          expect(rsrc.provider.speed).to eq(:absent)
          expect(rsrc.provider.duplex).to eq(:absent)
        end
      end

      it 'sets the provider instance of the managed resource' do
        subject
        expect(resources['Ethernet1'].provider.description)
          .to eq('test interface')
        expect(resources['Ethernet1'].provider.enable).to eq :true
        expect(resources['Ethernet1'].provider.speed).to eq '100g'
        expect(resources['Ethernet1'].provider.duplex).to eq :full
      end

      it 'does not set the provider instance of the unmanaged resource' do
        subject
        expect(resources['Ethernet2'].provider.description).to eq :absent
        expect(resources['Ethernet2'].provider.enable).to eq :absent
        expect(resources['Ethernet2'].provider.speed).to eq :absent
        expect(resources['Ethernet2'].provider.duplex).to eq :absent
      end
    end
  end

  context 'resource (instance) methods' do
    describe '#description=(value)' do
      it 'updates description in the provider' do
        expect(api).to receive(:set_description).with(resource[:name],
                                                      value: 'foo')
        provider.description = 'foo'
        expect(provider.description).to eq('foo')
      end
    end

    describe '#speed=(value)' do
      let(:name) { 'Ethernet1' }
      it 'updates speed in the provider' do
        expect(api).to receive(:set_speed).with(name,
                                                value: 'auto',
                                                forced: false)
        provider.speed = :auto
        provider.flush
        expect(provider.speed).to eq(:auto)
      end
    end

    describe '#duplex=(value)' do
      let(:name) { 'Ethernet1' }
      it 'updates duplex in the provider' do
        expect(api).to receive(:set_speed).with(name,
                                                value: 'auto',
                                                forced: false)
        provider.duplex = :auto
        provider.flush
        expect(provider.duplex).to eq(:auto)
      end
    end

    describe '#enable=(value)' do
      let(:name) { 'Ethernet1' }
      %i[true false].each do |val|
        it 'updates enable in the provider' do
          value = val == :false
          expect(api).to receive(:set_shutdown).with(name, value: value)
          provider.enable = val
          expect(provider.enable).to eq(val)
        end
      end
    end
  end
end
