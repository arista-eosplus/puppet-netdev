# encoding: utf-8

require 'spec_helper'

# CommonMethods should be mixed into the EosApi class
describe PuppetX::NetDev::EosApi do
  let(:api) { PuppetX::NetDev::EosApi.new }
  let(:prefix) { %w(enable configure) }

  describe '#running_config' do
    subject { api.running_config }

    before :each do
      allow(api).to receive(:eapi_action)
        .with(['enable', 'show running-config'],
              'show running configuration',
              format: 'text')
        .and_return([{ 'output' => 'empty' }])
    end

    it 'calls eapi_action to obtain the running configuration' do
      expect(api).to receive(:eapi_action)
        .with(['enable', 'show running-config'],
              'show running configuration',
              format: 'text')
        .and_return([{ 'output' => 'empty' }])
      subject
    end

    it 'returns the output key from the EAPI' do
      expect(subject).to eq('empty')
    end
  end
end
