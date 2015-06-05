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

describe Puppet::Type.type(:tacacs_server).provider(:eos) do

  let(:type) { Puppet::Type.type(:tacacs_server) }

  # Allow text cases to override resource attributes
  let :resource_override do
    {}
  end

  let :resource_hash do
    {
      ensure: :present,
      name: '127.0.0.1/49',
      hostname: '127.0.0.1',
      port: 49,
      timeout: 10,
      key: '1513090F557878',
      key_format: 7
    }.merge(resource_override)
  end

  let(:resource) { type.new(resource_hash) }
  let(:provider) { described_class.new(resource) }

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

  it_behaves_like 'provider exists?'

  context 'class methods' do
    before { allow(api).to receive(:get).and_return(tacacs) }

    describe '.instances' do

      subject { described_class.instances }

      it { is_expected.to be_an Array }
      it 'size is 4' do
        expect(subject.size).to eq(4)
      end
      it 'sets the name parameter as <hostname>/<port>' do
        subject.each { |i| expect(i.name).to match /^.*?\/\d+$/ }
      end
      it 'one instance, 1.2.3.4/4949 has single_connection == :true' do
        instance = subject.find { |i| i.single_connection == :true }
        expect(instance).not_to be_nil
        expect(instance.hostname).to eq '1.2.3.4'
        expect(instance.port).to eq 4949
      end
    end
  end

  context 'resource (instance) methods' do

    describe '#flush' do
    before :each do
      allow(api).to receive(:update_server).and_return(true)
      allow(api).to receive(:remove_server).and_return(true)
    end

      context 'after create' do
        subject do
          provider.create
          provider.flush
        end

        it 'calls #update_server' do
          expect(api).to receive(:update_server)
            .with(include(hostname: '127.0.0.1'))
            .and_return(true)
          subject
        end

        context 'when single_connection is :true' do
          let(:resource_override) do
            { single_connection: :true }
          end
          it 'calls #update_server with multiplex: true' do
            expect(api).to receive(:update_server)
              .with(include(multiplex: true))
              .and_return(true)
            subject
          end
        end
      end

      context 'after destroy' do
        let :resource_override do
          { ensure: :absent }
        end

        subject do
          provider.destroy
          provider.flush
        end

        it 'calls remove_server' do
          expect(api).to receive(:remove_server)
            .with(include(hostname: '127.0.0.1'))
            .and_return(true)
          subject
        end
      end
    end
  end
end
