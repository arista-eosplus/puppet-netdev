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

describe Puppet::Type.type(:snmp_community).provider(:eos) do
  # Puppet RAL memoized methods
  let(:resource) do
    resource_hash = {
      ensure: :present,
      name: 'public',
      group: :ro,
      acl: 'foo',
      provider: described_class.name
    }
    Puppet::Type.type(:snmp_community).new(resource_hash)
  end

  let(:provider) { resource.provider }

  let(:api) { double('snmp') }

  def snmp
    snmp = Fixtures[:snmp]
    return snmp if snmp
    fixture('snmp', dir: File.dirname(__FILE__))
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

      it 'has only one entry' do
        expect(subject.size).to eq 1
      end

      it 'has an instance for public' do
        instance = subject.find { |p| p.name == 'public' }
        expect(instance).to be_a described_class
      end

      context 'snmp_community { "public": }' do
        subject { described_class.instances.find { |p| p.name == 'public' } }

        include_examples 'provider resource methods',
                         ensure: :present,
                         name: 'public',
                         group: :ro,
                         acl: 'foo',
                         exists?: true
      end
    end

    describe '.prefetch' do
      let :resources do
        {
          'public' => Puppet::Type.type(:snmp_community).new(name: 'public'),
          'private' => Puppet::Type.type(:snmp_community).new(name: 'private')
        }
      end

      subject { described_class.prefetch(resources) }

      it 'resource providers are absent prior to calling .prefetch' do
        resources.values.each do |rsrc|
          expect(rsrc.provider.group).to eq(:absent)
          expect(rsrc.provider.acl).to eq(:absent)
        end
      end

      it 'sets the provider instance of the managed resource' do
        subject
        expect(resources['public'].provider.name).to eq('public')
        expect(resources['public'].provider.group).to eq(:ro)
        expect(resources['public'].provider.acl).to eq('foo')
        expect(resources['public'].provider.exists?).to be_truthy
      end

      it 'does not set the provider instance of the unmanaged resource' do
        subject
        expect(resources['private'].provider.name).to eq('private')
        expect(resources['private'].provider.group).to eq(:absent)
        expect(resources['private'].provider.acl).to eq(:absent)
        expect(resources['private'].provider.exists?).to be_falsey
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
          allow(api).to receive(:get).and_return(snmp)
          described_class.instances.first
        end
        it { is_expected.to be_truthy }
      end
    end

    describe '#create' do
      let(:vid) { resource[:name] }

      before do
        allow(api).to receive_messages(
          set_community_access: true,
          set_community_acl: true
        )
        expect(api).to receive(:add_community).with(resource[:name])
      end

      it 'sets ensure to :present' do
        provider.create
        expect(provider.ensure).to eq(:present)
      end

      it 'sets group to the resource value' do
        provider.create
        expect(provider.group).to eq(:ro)
      end

      it 'sets acl to the resource value' do
        provider.create
        expect(provider.acl).to eq('foo')
      end
    end

    describe '#destroy' do
      it 'sets ensure to :absent' do
        expect(api).to receive(:remove_community).with(resource[:name])
        provider.destroy
        expect(provider.ensure).to eq(:absent)
      end
    end

    describe '#group=(value)' do
      it 'updates group in the provider' do
        expect(api).to receive(:set_community_access).with(resource[:name], 'rw')
        provider.group = :rw
        expect(provider.group).to eq(:rw)
      end
    end

    describe '#acl=(value)' do
      it 'updates acl in the provider' do
        expect(api).to receive(:set_community_acl).with(resource[:name],
                                                        value: 'foo')
        provider.acl = 'foo'
        expect(provider.acl).to eq('foo')
      end
    end
  end
end
