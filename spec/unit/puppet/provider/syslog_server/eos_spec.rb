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

describe Puppet::Type.type(:syslog_server).provider(:eos) do
  let(:type) { Puppet::Type.type(:syslog_server) }

  # Puppet RAL memoized methods
  let(:resource_hash) do
    {
      name: '192.0.2.2',
      ensure: :present,
      port: '514',
      vrf: 'default'
    }
  end

  let(:resource) { type.new(resource_hash) }
  # let(:provider) { resource.provider }
  let(:provider) { described_class.new(resource) }

  let(:api) { double('logging') }

  def logging
    logging = Fixtures[:logging]
    return logging if logging
    fixture('api_logging')
  end

  # Stub the Api method class.
  before :each do
    allow(described_class.node).to receive(:api).with('logging').and_return(api)
    allow(provider.node).to receive(:api).with('logging').and_return(api)
  end

  context 'class methods' do
    before { allow(api).to receive(:get).and_return(logging) }

    describe '.instances' do
      subject { described_class.instances }

      it { is_expected.to be_an Array }

      it 'has two instances' do
        expect(subject.size).to eq(2)
      end

      it 'has an instance for 192.0.2.2 514 default' do
        instance = subject.find { |p| p.name == '192.0.2.2 514 default' }
        expect(instance).to be_a described_class
      end

      context 'syslog_server { "192.0.2.2 514 default": }' do
        let(:res_name) { '192.0.2.2 514 default' }
        subject { described_class.instances.find { |p| p.name == res_name } }

        include_examples 'provider resource methods',
                         name: res_name
      end
    end

    describe '.prefetch' do
      let :resources do
        {
          '192.0.2.2 514 default' => Puppet::Type.type(:syslog_server) .new(
            name: '192.0.2.2 514 default'
          ),
          '192.0.2.10 514 default' => Puppet::Type.type(:syslog_server) .new(
            name: '192.0.2.10 514 default'
          )
        }
      end

      subject { described_class.prefetch(resources) }

      it 'sets the provider instance of the managed resource' do
        subject
        expect(resources['192.0.2.2 514 default'].provider.name).to eq(
          '192.0.2.2 514 default'
        )
        expect(resources['192.0.2.2 514 default'].provider.exists?).to be_truthy
      end

      it 'does not set the provider instance of the unmanaged resource' do
        subject
        expect(resources['192.0.2.10 514 default'].provider.name).to eq(
          '192.0.2.10 514 default'
        )
        expect(resources['192.0.2.10 514 default'].provider.exists?)
          .to be_falsey
      end
    end
  end

  # it_behaves_like 'provider exists?'

  context 'resource (instance) methods' do
    describe '#exists?' do
      subject { provider.exists? }

      context 'when the resource does not exist on the system' do
        it { is_expected.to be_falsey }
      end

      context 'when the resource exists on the system' do
        let(:provider) do
          allow(api).to receive(:get).and_return(logging)
          described_class.instances.first
        end
        it { is_expected.to be_truthy }
      end
    end

    describe '#create' do
      it 'sets ensure to :present' do
        expect(api).to receive(:add_host).with(
          resource[:name].split(' ')[0], port: '514', vrf: 'default'
        )
                                         .and_return(true)
        provider.create
        provider.flush
        expect(provider.ensure).to eq(:present)
      end
    end

    describe '#destroy' do
      it 'sets ensure to :absent' do
        expect(api).to receive(:remove_host).with(
          resource[:name].split(' ')[0], port: '514', vrf: 'default'
        )
        provider.destroy
        provider.flush
        expect(provider.ensure).to eq(:absent)
      end
    end
  end
end
