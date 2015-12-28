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

describe Puppet::Type.type(:domain_name).provider(:eos) do
  # Puppet RAL memoized methods
  let(:resource) do
    resource_hash = {
      name: 'arista.com',
      provider: described_class.name
    }
    Puppet::Type.type(:domain_name).new(resource_hash)
  end

  let(:provider) { resource.provider }

  let(:api) { double('dns') }

  def dns
    dns = Fixtures[:dns]
    return dns if dns
    fixture('dns')
  end

  # Stub the Api method class to obtain all vlans.
  before :each do
    allow(described_class.node).to receive(:api).with('dns').and_return(api)
    allow(provider.node).to receive(:api).with('dns').and_return(api)
  end

  context 'class methods' do
    before { allow(api).to receive(:get).and_return(dns) }

    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }

      it 'has only one entry' do
        expect(subject.size).to eq 1
      end

      it 'has an instance for dns settings' do
        instance = subject.find { |p| p.name == 'arista.com' }
        expect(instance).to be_a described_class
      end

      context "domain_name { 'settings': }" do
        subject { described_class.instances.find { |p| p.name == 'arista.com' } }

        include_examples 'provider resource methods',
                         name: 'arista.com'
      end
    end

    describe '.prefetch' do
      let :resources do
        {
          'arista.com' => Puppet::Type.type(:domain_name).new(name: 'arista.com'),
          'arista.net' => Puppet::Type.type(:domain_name).new(name: 'arista.net')
        }
      end

      subject { described_class.prefetch(resources) }

      it 'sets the provider instance of the managed resource' do
        subject
        expect(resources['arista.com'].provider.name).to eq('arista.com')
        expect(resources['arista.com'].provider.exists?).to be_truthy
      end

      it 'does not set the provider instance of the unmanaged resource' do
        subject
        expect(resources['arista.net'].provider.name).to eq('arista.net')
        expect(resources['arista.net'].provider.exists?).to be_falsey
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
          allow(api).to receive(:get).and_return(dns)
          described_class.instances.first
        end
        it { is_expected.to be_truthy }
      end
    end

    describe '#create' do
      it 'sets ensure to :present' do
        expect(api).to receive(:set_domain_name).with(value: resource[:name])
        provider.create
        expect(provider.ensure).to eq(:present)
      end
    end

    describe '#destroy' do
      it 'sets ensure to :absent' do
        expect(api).to receive(:set_domain_name).with(no_args)
        provider.destroy
        expect(provider.ensure).to eq(:absent)
      end
    end
  end
end
