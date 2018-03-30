#
# Copyright (c) 2014-2017, Arista Networks, Inc.
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

describe Puppet::Type.type(:ntp_server).provider(:eos) do
  let :resource do
    resource_hash = {
      name: '1.2.3.4',
      key: 1,
      maxpoll: 8,
      minpoll: 5,
      prefer: true,
      source_interface: 'Ethernet1',
      vrf: 'test'
    }
    Puppet::Type.type(:ntp_server).new(resource_hash)
  end

  let(:provider) { resource.provider }

  let(:api) { double('ntp') }

  def ntp
    ntp = Fixtures[:ntp]
    return ntp if ntp
    fixture('ntp')
  end

  before :each do
    allow(described_class.node).to receive(:api).with('ntp').and_return(api)
    allow(provider.node).to receive(:api).with('ntp').and_return(api)
  end

  context 'class methods' do
    before { allow(api).to receive(:get).and_return(ntp) }

    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }

      it 'has one instance' do
        expect(subject.size).to eq(1)
      end

      it 'contains ntp_server[1.2.3.4]' do
        instance = subject.find { |p| p.name == '1.2.3.4' }
        expect(instance).to be_a described_class
      end

      describe 'ntp_server[1.2.3.4]' do
        subject do
          described_class.instances.find { |p| p.name == '1.2.3.4' }
        end

        include_examples 'provider resource methods',
                         key: 1,
                         prefer: :true,
                         maxpoll: 8,
                         minpoll: 5,
                         source_interface: 'Ethernet1',
                         vrf: 'test'
      end
    end

    describe '.prefetch' do
      let(:resources) do
        {
          '1.2.3.4' => Puppet::Type.type(:ntp_server).new(name: '1.2.3.4'),
          '5.6.7.8' => Puppet::Type.type(:ntp_server).new(name: '5.6.7.8')
        }
      end

      subject { described_class.prefetch(resources) }

      it 'resource providers are absent prior to calling .prefetch' do
        resources.values.each do |rsrc|
          expect(rsrc.provider.prefer).to eq(:absent)
        end
      end

      it 'sets the provider instance of the managed resource' do
        subject
        expect(resources['1.2.3.4'].provider.name).to eq('1.2.3.4')
        expect(resources['1.2.3.4'].provider.exists?).to be_truthy
        expect(resources['1.2.3.4'].provider.prefer).to eq(:true)
      end

      it 'does not set the provider instance of the unmanaged resource' do
        subject
        expect(resources['5.6.7.8'].provider.name).to eq '5.6.7.8'
        expect(resources['5.6.7.8'].provider.exists?).to be_falsy
        expect(resources['5.6.7.8'].provider.prefer).to eq :absent
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
          allow(api).to receive(:get).and_return(ntp)
          described_class.instances.first
        end
        it { is_expected.to be_truthy }
      end
    end

    describe '#create' do
      it 'creates a new server when ensure :present' do
        resource[:ensure] = :present
        expect(api).to receive(:add_server)
          .with('1.2.3.4', false, key: '1', prefer: 'true', maxpoll: '8',
                                  minpoll: '5', source_interface: 'Ethernet1',
                                  vrf: 'test').and_return(true)
        provider.create
        provider.flush
        expect(provider.name).to eq('1.2.3.4')
        expect(provider.ensure).to eq(:present)
        expect(provider.key).to eq(1)
        expect(provider.prefer).to eq(:true)
        expect(provider.maxpoll).to eq(8)
        expect(provider.minpoll).to eq(5)
        expect(provider.source_interface).to eq('Ethernet1')
        expect(provider.vrf).to eq('test')
      end

      it 'raise an error when rbeapi cannot set configuration' do
        resource[:ensure] = :present
        expect(api).to receive(:add_server)
          .with('1.2.3.4', false, key: '1', prefer: 'true', maxpoll: '8',
                                  minpoll: '5', source_interface: 'Ethernet1',
                                  vrf: 'test').and_return(false)
        provider.create
        expect { provider.flush }
          .to raise_error(Puppet::Error, 'Unable to set Ntp_server[1.2.3.4]')
        expect(provider.name).to eq('1.2.3.4')
      end
    end

    describe '#destroy' do
      it 'deletes a server when ensure :absent' do
        resource[:ensure] = :absent
        expect(api).to receive(:remove_server).with('1.2.3.4', 'test')
        provider.destroy
        provider.flush
        expect(provider.ensure).to eq(:absent)
      end
    end
  end
end
