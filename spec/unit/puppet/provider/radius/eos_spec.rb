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

describe Puppet::Type.type(:radius).provider(:eos) do

  # Puppet RAL memoized methods
  let(:resource) do
    resource_hash = {
      name: 'settings',
      enable: :true,
      provider: described_class.name
    }
    Puppet::Type.type(:radius).new(resource_hash)
  end

  let(:provider) { resource.provider }

  let(:api) { double('radius') }

  def radius
    radius = Fixtures[:radius]
    return radius if radius
    file = File.join(File.dirname(__FILE__), 'fixture_api_radius.json')
    Fixtures[:radius] = JSON.load(File.read(file))
  end

  # Stub the Api method class.
  before :each do
    allow(described_class.node).to receive(:api).with('radius').and_return(api)
    allow(provider.node).to receive(:api).with('radius').and_return(api)
  end

  context 'class methods' do

    before { allow(api).to receive(:get).and_return(radius) }

    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }

      it 'has one instance' do
        expect(subject.size).to eq(1)
      end

      it 'has an instance for settings' do
        instance = subject.find { |p| p.name == 'settings' }
        expect(instance).to be_a described_class
      end

      context 'radius { settings: }' do
        subject { described_class.instances.find { |p| p.name == 'settings' } }

        include_examples 'provider resource methods',
                         name: 'settings',
                         enable: :true
      end
    end

    describe '.prefetch' do
      let :resources do
        {
          'settings' => Puppet::Type.type(:radius).new(name: 'settings'),
          'alternative' => Puppet::Type.type(:radius).new(name: 'alternative')
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
        expect(resources['settings'].provider.name).to eq('settings')
        expect(resources['settings'].provider.exists?).to be_truthy
        expect(resources['settings'].provider.enable).to be_truthy
      end

      it 'does not set the provider instance of the unmanaged resource' do
        subject
        expect(resources['alternative'].provider.name).to eq('alternative')
        expect(resources['alternative'].provider.exists?).to be_falsey
        expect(resources['alternative'].provider.enable).to eq(:absent)
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
          allow(api).to receive(:get).and_return(radius)
          described_class.instances.first
        end
        it { is_expected.to be_truthy }
      end
    end

    describe '#enable' do
      it 'sets enable to :true in the provider' do
        expect(api).to receive(:set_enable).with(value: true)
        provider.enable = :true
        expect(provider.enable).to eq(:true)
      end

      it 'sets enable to :false in the provider' do
        expect(api).to receive(:set_enable).with(value: false)
        provider.enable = :false
        expect(provider.enable).to eq(:false)
      end
    end
  end
end
