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

describe Puppet::Type.type(:tacacs_global).provider(:eos) do

  let(:resource) do
    resource_hash = {
      name: 'settings',
      enable: true,
      key: '070E234F1F5B4A',
      key_format: 7,
      timeout: 30,
      provider: described_class.name
    }
    Puppet::Type.type(:tacacs_global).new(resource_hash)
  end

  let(:provider) { resource.provider }

  let(:api) { double('tacacs') }

  def tacacs
    tacacs = Fixtures[:tacacs]
    return tacacs if tacacs
    fixture('eapi_tacacs_servers')
  end

  before :each do
    allow(described_class.node).to receive(:api).with('tacacs').and_return(api)
    allow(provider.node).to receive(:api).with('tacacs').and_return(api)
  end

  context 'class methods' do
    before { allow(api).to receive(:get).and_return(tacacs) }

    describe '.instances' do

      subject { described_class.instances }

      it { is_expected.to be_an Array }
      it { expect(subject.size).to eq(1) }

      describe 'the single returned instance' do
        subject { described_class.instances.first }

        it { is_expected.to be_a described_class }
        it 'has the name "settings"' do
          expect(subject.name).to eq 'settings'
        end
        it 'key is 070E234F1F5B4A' do
          expect(subject.key).to eq '070E234F1F5B4A'
        end
        it 'key_format is 7 (hashed)' do
          expect(subject.key_format).to eq 7
        end
        it 'timeout is 7' do
          expect(subject.timeout).to eq 7
        end
      end
    end
  end

  context 'resource (instance) methods' do

    #describe '#key=(value)' do
    #  it 'updates the global key' do
    #    expect(api).to receive(:set_global_key).with(key_format: 0, value: '070E234F1F5B4A')
    #    provider.key = '070E234F1F5B4A'
    #    expect(provider.key).to eq('070E234F1F5B4A')
    #  end
    #end


    describe '#flush' do
      before :each do
        allow(api).to receive(:set_global_key).and_return(true)
        allow(api).to receive(:set_global_timeout).and_return(true)
      end

      context 'after updating the key' do

        subject do
          provider.key = 'updatedkey'
          provider.key_format = 5
          provider.flush
        end

        it 'calls #set_global_key to configure the key' do
          expect(api).to receive(:set_global_key)
            .with(include(value: 'updatedkey'))
          subject
        end
        it 'does not update the timeout' do
          expect(api).not_to receive(:set_global_timeout)
          subject
        end
      end

      context 'after updating the timeout' do
        subject do
          provider.timeout = 120
          provider.flush
        end

        it 'does not update the key' do
          expect(api).not_to receive(:set_global_key)
          subject
        end
        it 'calls #set_timeout to configure the timeout' do
          expect(api).to receive(:set_global_timeout)
            .with(include(value: 120))
          subject
        end
      end
    end
  end
end
