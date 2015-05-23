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

describe Puppet::Type.type(:tacacs_server_group).provider(:eos) do

  let(:type) { Puppet::Type.type(:tacacs_server_group) }

  # Allow text cases to override resource attributes
  let :resource_override do
    {}
  end

  let :resource_hash do
    {
      ensure: :present,
      name: 'TAC-SV9',
      servers: ['10.11.12.13/1024', '10.11.12.13/49']
    }.merge(resource_override)
  end

  let(:resource) { type.new(resource_hash) }
  let(:provider) { described_class.new(resource) }

  let(:api) { double('aaa') }

  def aaa
    aaa = Fixtures[:aaa]
    return aaa if aaa
    fixture('eapi_tacacs_server_groups')
  end

  before :each do
    allow(described_class.node).to receive(:api).with('aaa').and_return(api)
    allow(provider.node).to receive(:api).with('aaa').and_return(api)
  end

  it_behaves_like 'provider exists?'

  context 'class methods' do
    before { allow(api).to receive(:get).and_return(aaa) }

    describe '.instances' do

      subject { described_class.instances }

      it { is_expected.to be_an Array }
      include_examples 'attribute', size: 3
    end
  end

  context 'resource (instance) methods' do

    describe '#flush' do
      before :each do
        allow(api).to receive_message_chain(:groups, :create).and_return(true)
        allow(api).to receive_message_chain(:groups, :set_servers).and_return(true)
        allow(api).to receive_message_chain(:groups, :delete).and_return(true)
      end

      context 'after create' do
        subject do
          provider.create
        end

        it 'calls #create' do
          expect(api).to receive_message_chain(:groups, :create)
            .with('TAC-SV9', 'tacacs+')
            .and_return(true)
          subject
        end
      end

      context 'after destroy' do
        let :resource_override do
          { ensure: :absent }
        end

        subject do
          provider.destroy
        end

        it 'calls #delete' do
          expect(api).to receive_message_chain(:groups, :delete)
            .with(include('TAC-SV9'))
            .and_return(true)
          subject
        end
      end

      context 'after updating servers' do
        subject do
          provider.create
          provider.servers=[]
        end

        it 'calls #set_servers' do
          expect(api).to receive_message_chain(:groups, :set_servers)
            .with('TAC-SV9', [])
            .and_return(true)
          subject
        end
      end
    end
  end
end
