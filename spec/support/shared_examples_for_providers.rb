# encoding: utf-8
RSpec.shared_examples 'provider resource methods' do |opts = {}|
  opts.each_pair do |method, value|
    it "#{method} is #{value}" do
      expect(subject.send(method)).to eq(value)
    end
  end
end

RSpec.shared_examples 'provider exists?' do
  describe '#exists?' do
    let(:provider) { described_class.new(resource_hash) }
    subject { provider.exists? }

    context 'when ensure is absent' do
      let(:resource_override) { { ensure: :absent } }
      it { is_expected.to eq(false) }
    end

    context 'when ensure is present' do
      let(:resource_override) { { ensure: :present } }
      it { is_expected.to eq(true) }
    end
  end
end

RSpec.shared_examples 'provider instances' do |opts = { size: 0 }|
  it { is_expected.to be_an Array }
  it "returns #{opts[:size]} instances" do
    expect(subject.size).to eq(opts[:size])
  end
  it 'returns instances with ensure => :present' do
    subject.each { |p| expect(p.ensure).to eq(:present) }
  end
end

RSpec.shared_examples 'attribute' do |opts = { }|
  opts.each do |attribute, expected_value|
    it "##{attribute} equates to #{expected_value}" do
      expect(subject.send(attribute.intern)).to eq(expected_value)
    end
  end
end
