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

describe Puppet::Type.type(:snmp_notification).provider(:eos) do

  # Puppet RAL memoized methods
  let(:resource) do
    resource_hash = {
      name: 'all',
      enable: :true,
      provider: described_class.name
    }
    Puppet::Type.type(:snmp_notification).new(resource_hash)
  end

  let(:provider) { resource.provider }

  let(:api) { double('snmp') }

  def snmp
    snmp = Fixtures[:snmp]
    return snmp if snmp
    fixture('eapi_snmp')
  end

  before :each do
    allow(described_class.node).to receive(:api).with('snmp').and_return(api)
    allow(provider.node).to receive(:api).with('snmp').and_return(api)
  end

  context 'class methods' do

    before { allow(api).to receive(:get).and_return(snmp) }

    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }

      it 'has at least 1 entry' do
        expect(subject.size).to be >= 1
      end

      it 'has an instance for all' do
        instance = subject.find { |p| p.name == 'all' }
        expect(instance).to be_a described_class
      end

      context 'snmp_notification { "all": }' do
        subject { described_class.instances.find { |p| p.name == 'all' } }

        include_examples 'provider resource methods',
                         name: 'all',
                         enable: :false
      end
    end

    describe '.prefetch' do
      let :resources do
        {
          'all' => Puppet::Type.type(:snmp_notification).new(name: 'all'),
          'bgp' => Puppet::Type.type(:snmp_notification).new(name: 'bgp'),
        }
      end

      subject { described_class.prefetch(resources) }

      it 'resource providers are absent prior to calling .prefetch' do
        resources.values.each do |rsrc|
          expect(rsrc.provider.enable).to eq(:absent)
        end
      end

      it 'sets the provider instance of the managed resource' do
        subject
        expect(resources['all'].provider.name).to eq('all')
        expect(resources['all'].provider.enable).to eq(:false)
      end

      it 'does not set the provider instance of the unmanaged resource' do
        subject
        expect(resources['bgp'].provider.name).to eq('bgp')
        expect(resources['bgp'].provider.enable).to eq(:absent)
      end
    end
  end

  context 'resource (instance) methods' do

    describe '#enable=(value)' do
      it 'updates enable in the provider' do
        expect(api).to receive(:set_notification).with(name: resource[:name], state: 'off')
        provider.enable = :false
        expect(provider.enable).to eq(:false)
      end
    end

  end
end
