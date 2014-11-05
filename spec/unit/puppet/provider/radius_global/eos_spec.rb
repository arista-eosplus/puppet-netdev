# encoding: utf-8

require 'spec_helper'

describe Puppet::Type.type(:radius_global).provider(:eos) do
  let(:radius) { PuppetX::Eos::Radius.new(PuppetX::Eos::Eapi.new) }

  describe 'class methods' do
    describe '.instances' do
      before :each do
        allow(described_class.eapi).to receive(:Radius).and_return(radius)
        allow(radius).to receive(:getall)
          .and_return(fixture(:eapi_radius_getall_configured))
      end

      subject { described_class.instances }

      it { is_expected.to be_an Array }
      it { expect(subject.size).to eq(1) }

      describe 'the single returned instance' do
        subject { described_class.instances.first }

        it { is_expected.to be_a described_class }
        it 'has the name "settings"' do
          expect(subject.name).to eq 'settings'
        end
        it 'enable is true' do
          expect(subject.enable).to eq true
        end
        it 'key is 070E234F1F5B4A' do
          expect(subject.key).to eq '070E234F1F5B4A'
        end
        it 'key_format is 7 (hashed)' do
          expect(subject.key_format).to eq 7
        end
        it 'timeout is 50' do
          expect(subject.timeout).to eq 50
        end
        it 'retransmit_count is 5' do
          expect(subject.retransmit_count).to eq 5
        end
      end
    end
  end
end
