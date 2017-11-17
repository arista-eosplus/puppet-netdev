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

describe Puppet::Type.type(:syslog_settings).provider(:eos) do
  # Puppet RAL memoized methods
  let(:resource) do
    resource_hash = {
      name: 'settings',
      console: 3,
      enable: :true,
      monitor: 2,
      time_stamp_units: 'seconds',
      source_interface: ['Ethernet6', 'Management1'],
      vrf: ['blue', 'default'],
      provider: described_class.name
    }
    Puppet::Type.type(:syslog_settings).new(resource_hash)
  end

  let(:provider) { resource.provider }

  let(:api) { double('logging') }

  def logging
    logging = Fixtures[:logging]
    return logging if logging
    fixture('api_logging')
  end

  before :each do
    allow(described_class.node).to receive(:api).with('logging').and_return(api)
    allow(provider.node).to receive(:api).with('logging').and_return(api)
  end

  context 'class methods' do
    before { allow(api).to receive(:get).and_return(logging) }

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

      context 'syslog_settings { settings: }' do
        subject { described_class.instances.find { |p| p.name == 'settings' } }

        include_examples 'provider resource methods',
                         name: 'settings',
                         console: 3,
                         monitor: 2,
                         time_stamp_units: 'milliseconds',
                         source_interface: ['Ethernet6', 'Management1'],
                         vrf: ['blue', 'default'],
                         enable: :true
      end
    end

    describe '.prefetch' do
      let :resources do
        {
          'settings' => Puppet::Type.type(:syslog_settings)
                                    .new(name: 'settings'),
          'alternative' => Puppet::Type.type(:syslog_settings)
                                       .new(name: 'alternative')
        }
      end
      subject { described_class.prefetch(resources) }

      it 'resource providers are absent prior to calling .prefetch' do
        resources.values.each do |rsrc|
          expect(rsrc.provider.enable).to eq(:absent)
          expect(rsrc.provider.console).to eq(:absent)
          expect(rsrc.provider.monitor).to eq(:absent)
          expect(rsrc.provider.time_stamp_units).to eq(:absent)
          expect(rsrc.provider.source_interface).to eq(:absent)
          expect(rsrc.provider.vrf).to eq(:absent)
        end
      end

      it 'sets the provider instance of the managed resource' do
        subject
        expect(resources['settings'].provider.name).to eq('settings')
        expect(resources['settings'].provider.exists?).to be_truthy
        expect(resources['settings'].provider.enable).to be_truthy
        expect(resources['settings'].provider.console).to eq(3)
        expect(resources['settings'].provider.monitor).to eq(2)
        expect(resources['settings'].provider.time_stamp_units)
          .to eq('milliseconds')
      end

      it 'does not set the provider instance of the unmanaged resource' do
        subject
        expect(resources['alternative'].provider.name).to eq('alternative')
        expect(resources['alternative'].provider.exists?).to be_falsey
        expect(resources['alternative'].provider.enable).to eq(:absent)
        expect(resources['alternative'].provider.console).to eq(:absent)
        expect(resources['alternative'].provider.monitor).to eq(:absent)
        expect(resources['alternative'].provider.source_interface)
          .to eq(:absent)
        expect(resources['alternative'].provider.vrf).to eq(:absent)
        expect(resources['alternative'].provider.time_stamp_units)
          .to eq(:absent)
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
          allow(api).to receive(:get).and_return(logging)
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

    describe '#set_console=(value)' do
      it 'updates console in the provider' do
        expect(api).to receive(:set_console).with(level: 5)
        provider.console = 5
        expect(provider.console).to eq(5)
      end
    end

    describe '#set_monitor=(value)' do
      it 'updates monitor in the provider' do
        expect(api).to receive(:set_monitor).with(level: 7)
        provider.monitor = 7
        expect(provider.monitor).to eq(7)
      end
    end

    describe '#set_time_stamp_units=(value)' do
      it 'updates time_stamp_units in the provider' do
        expect(api).to receive(:set_time_stamp_units).with(units: 'milliseconds')
        provider.time_stamp_units = 'milliseconds'
        expect(provider.time_stamp_units).to eq('milliseconds')
      end
    end

    describe '#set_source_interface=(value)' do
      it 'updates source_interface in the provider' do
        expect(api).to receive(:set_source_interface).with({"default"=>"Management1", "red"=>"Ethernet5"})
        provider.source_interface = ['Management1', 'Ethernet5']
        provider.vrf = ['default', 'red']
        provider.flush
        expect(provider.source_interface).to eq(['Management1', 'Ethernet5'])
      end
    end

    describe '#set_vrf=(value)' do
      it 'updates vrf in the provider' do
        expect(api).to receive(:set_source_interface).with({"default"=>"Management1", "blue"=>"Ethernet5"})
        provider.source_interface = ['Management1', 'Ethernet5']
        provider.vrf = ['default', 'blue']
        provider.flush
        expect(provider.vrf).to eq(['default', 'blue'])
      end
    end
  end
end
