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

describe Puppet::Type.type(:ntp_auth_key).provider(:eos) do
  let :resource do
    resource_hash = {
      name: '1',
      algorithm: 'md5',
      mode: 7,
      password: '06120A3258'
    }
    Puppet::Type.type(:ntp_auth_key).new(resource_hash)
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

      it 'contains ntp_auth_key[1]' do
        instance = subject.find { |p| p.name == '1' }
        expect(instance).to be_a described_class
      end

      describe 'ntp_auth_key[1]' do
        subject do
          described_class.instances.find { |p| p.name == '1' }
        end

        include_examples 'provider resource methods',
                         algorithm: 'md5',
                         mode: 7,
                         password: '06120A3258'
      end
    end

    describe '.prefetch' do
      let(:resources) do
        {
          '1' => Puppet::Type.type(:ntp_auth_key).new(name: '1'),
          '5' => Puppet::Type.type(:ntp_auth_key).new(name: '5')
        }
      end

      subject { described_class.prefetch(resources) }

      it 'resource providers are absent prior to calling .prefetch' do
        resources.values.each do |rsrc|
          expect(rsrc.provider.password).to eq(:absent)
        end
      end

      it 'sets the provider instance of the managed resource' do
        subject
        expect(resources['1'].provider.name).to eq('1')
        expect(resources['1'].provider.exists?).to be_truthy
        expect(resources['1'].provider.password).to eq('06120A3258')
      end

      it 'does not set the provider instance of the unmanaged resource' do
        subject
        expect(resources['5'].provider.name).to eq '5'
        expect(resources['5'].provider.exists?).to be_falsy
        expect(resources['5'].provider.password).to eq :absent
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
      it 'creates a new key when ensure :present' do
        resource[:ensure] = :present
        expect(api).to receive(:set_authentication_key)
          .with(key: '1', algorithm: 'md5', mode: '7', password: '06120A3258')
          .and_return(true)
        provider.create
        provider.flush
        expect(provider.name).to eq('1')
        expect(provider.ensure).to eq(:present)
        expect(provider.algorithm).to eq(:md5)
        expect(provider.mode).to eq(7)
        expect(provider.password).to eq('06120A3258')
      end

      it 'raises an error when rbeapi cannot set configuration' do
        resource[:ensure] = :present
        expect(api).to receive(:set_authentication_key)
          .with(key: '1', algorithm: 'md5', mode: '7', password: '06120A3258')
          .and_return(false)
        provider.create
        expect { provider.flush }
          .to raise_error(Puppet::Error, 'Unable to set Ntp_auth_key[1]')
      end

      it 'raises an error when passed an invalid algorithm' do
        resource[:ensure] = :present
        resource[:algorithm] = 'sha256'
        provider.create
        expect { provider.flush }
          .to raise_error(Puppet::Error, 'Unsupported algorithm in Ntp_auth_key[1]')
      end
    end

    describe '#destroy' do
      it 'deletes a server when ensure :absent' do
        resource[:ensure] = :absent
        expect(api).to receive(:set_authentication_key)
          .with(key: '1', enable: false, algorithm: 'md5', mode: '7',
                password: '06120A3258').and_return(true)
        provider.destroy
        provider.flush
        expect(provider.ensure).to eq(:absent)
      end
    end
  end
end
