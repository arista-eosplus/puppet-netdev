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

describe Puppet::Type.type(:radius_global).provider(:eos) do

  # Puppet RAL memoized methods
  let(:resource) do
    resource_hash = {
      name: 'settings',
      key: '044B0A151C36435C0D',
      key_format: 7,
      timeout: 10,
      retransmit_count: 10,
      provider: described_class.name
    }
    Puppet::Type.type(:radius_global).new(resource_hash)
  end

  let(:provider) { resource.provider }

  let(:api) { double('radius') }

  def radius
    radius = Fixtures[:radius]
    return radius if radius
    fixture('eapi_radius_servers')
  end

  before :each do
    allow(described_class.node).to receive(:api).with('radius').and_return(api)
    allow(provider.node).to receive(:api).with('radius').and_return(api)
  end

  context 'class methods' do

    before { allow(api).to receive(:get).and_return(radius) }

    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }

      it 'has only one entry' do
        expect(subject.size).to eq 1
      end

      it 'has an instance for settings' do
        instance = subject.find { |p| p.name == 'settings' }
        expect(instance).to be_a described_class
      end

      context 'radius_global { settings: }' do
        subject { described_class.instances.find { |p| p.name == 'settings' } }

        include_examples 'provider resource methods',
                         name: 'settings',
                         key: '044B0A151C36435C0D',
                         key_format: 7,
                         timeout: 10,
                         retransmit_count: 10
      end
    end

    describe '.prefetch' do
      let :resources do
        {
          'settings' => Puppet::Type.type(:radius_global).new(name: 'settings'),
          'alternate' => Puppet::Type.type(:radius_global).new(name: 'alternate'),
        }
      end

      subject { described_class.prefetch(resources) }

      it 'resource providers are absent prior to calling .prefetch' do
        resources.values.each do |rsrc|
          expect(rsrc.provider.key).to eq(:absent)
          expect(rsrc.provider.key_format).to eq(:absent)
          expect(rsrc.provider.timeout).to eq(:absent)
          expect(rsrc.provider.retransmit_count).to eq(:absent)
        end
      end

      it 'sets the provider instance of the managed resource' do
        subject
        expect(resources['settings'].provider.key).to eq('044B0A151C36435C0D')
        expect(resources['settings'].provider.key_format).to eq(7)
        expect(resources['settings'].provider.timeout).to eq(10)
        expect(resources['settings'].provider.retransmit_count).to eq(10)
      end

      it 'does not set the provider instance of the unmanaged resource' do
        subject
        expect(resources['alternate'].provider.key).to eq(:absent)
        expect(resources['alternate'].provider.key_format).to eq(:absent)
        expect(resources['alternate'].provider.timeout).to eq(:absent)
        expect(resources['alternate'].provider.retransmit_count).to eq(:absent)
      end
    end
  end

  context 'resource (instance) methods' do

    describe '#set_key=(value)' do
      it 'updates key in the provider' do
        expect(api).to receive(:set_global_key).with(value: 'foo', key_format: 0)
        provider.key = 'foo'
        provider.key_format = 0
        provider.flush
        expect(provider.key).to eq('foo')
        expect(provider.key_format).to eq(0)
      end
    end

    describe '#set_timeout=(value)' do
      it 'updates timeout in the provider' do
        expect(api).to receive(:set_global_timeout).with(value: 10)
        provider.timeout = 10
        provider.flush
        expect(provider.timeout).to eq(10)
      end
    end

    describe '#set_retransmit_count=(value)' do
      it 'updates retransmit_count in the provider' do
        expect(api).to receive(:set_global_retransmit).with(value: 10)
        provider.retransmit_count = 10
        provider.flush
        expect(provider.retransmit_count).to eq(10)
      end
    end
  end
end
