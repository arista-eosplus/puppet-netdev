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

describe Puppet::Type.type(:network_dns).provider(:eos) do
  # Puppet RAL memoized methods
  let(:resource) do
    resource_hash = {
      name: 'settings',
      domain: 'arista.com',
      search: ['arista.com'],
      servers: ['1.2.3.4'],
      provider: described_class.name
    }
    Puppet::Type.type(:network_dns).new(resource_hash)
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
        instance = subject.find { |p| p.name == 'settings' }
        expect(instance).to be_a described_class
      end

      context "network_dns { 'settings': }" do
        subject { described_class.instances.find { |p| p.name == 'settings' } }

        include_examples 'provider resource methods',
                         name: 'settings',
                         domain: 'arista.com',
                         search: ['arista.net'],
                         servers: ['1.2.3.4']
      end
    end

    describe '.prefetch' do
      let :resources do
        {
          'settings' => Puppet::Type.type(:network_dns)
                                    .new(name: 'settings'),
          'alternative' => Puppet::Type.type(:network_dns)
                                       .new(name: 'alternative')
        }
      end

      subject { described_class.prefetch(resources) }

      it 'resource providers are absent prior to calling .prefetch' do
        resources.values.each do |rsrc|
          expect(rsrc.provider.domain).to eq(:absent)
          expect(rsrc.provider.search).to eq(:absent)
          expect(rsrc.provider.servers).to eq(:absent)
        end
      end

      it 'sets the provider instance of the managed resource' do
        subject
        expect(resources['settings'].provider.name).to eq 'settings'
        expect(resources['settings'].provider.exists?).to be_truthy
        expect(resources['settings'].provider.domain).to eq('arista.com')
        expect(resources['settings'].provider.servers).to eq(['1.2.3.4'])
        expect(resources['settings'].provider.search).to eq(['arista.net'])
      end

      it 'does not set the provider instance of the unmanaged resource' do
        subject
        expect(resources['alternative'].provider.name).to eq('alternative')
        expect(resources['alternative'].provider.exists?).to be_falsey
        expect(resources['alternative'].provider.domain).to eq :absent
        expect(resources['alternative'].provider.servers).to eq :absent
        expect(resources['alternative'].provider.search).to eq :absent
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

    describe '#domain=(val)' do
      it 'updates domain in the provider' do
        expect(api).to receive(:set_domain_name).with(value: 'foo')
        provider.domain = 'foo'
        expect(provider.domain).to eq('foo')
      end
    end

    describe '#servers=(val)' do
      it 'updates servers in the provider' do
        expect(api).to receive(:set_name_servers).with(value: ['foo'])
        provider.servers = ['foo']
        expect(provider.servers).to eq(['foo'])
      end
    end

    describe '#search=(val)' do
      it 'updates search in the provider' do
        expect(api).to receive(:set_domain_list).with(value: ['foo'])
        provider.search = ['foo']
        expect(provider.search).to eq(['foo'])
      end
    end
  end
end
