require 'hutch/config'
require 'tempfile'

describe 'Configuration' do
  let(:config) { Hutch::Config.new }
  let(:new_value) { 'not-localhost' }

  describe 'getting an attribute' do
    context 'for valid attributes' do
      subject { config.mq_host }

      context 'with no overridden value' do
        it { should == 'localhost' }
      end

      context 'with an overridden value' do
        before  { config.mq_host = new_value }
        it { should == new_value }
      end
    end

    context 'for invalid attributes' do
      let(:invalid_get) { ->{ config.invalid_attr } }
      specify { invalid_get.should raise_error NoMethodError }
    end
  end

  describe 'setting an attribute' do
    context 'for valid attributes' do
      before  { config.mq_host = new_value }
      subject { config.mq_host }

      context 'sets value in user config hash' do
        it { should == new_value }
      end
    end

    context 'for invalid attributes' do
      let(:invalid_set) { ->{ config.invalid_attr = new_value } }
      specify { invalid_set.should raise_error Hutch::UnknownAttributeError }
    end
  end

  describe '.load_from_file' do
    let(:host) { 'broker.yourhost.com' }
    let(:username) { 'calvin' }
    let(:file) do
      Tempfile.new('configs.yaml', encoding: 'UTF-8').tap do |t|
        t.write(YAML.dump(config_data))
        t.rewind
      end
    end

    context 'when an attribute is invalid' do
      let(:config_data) { { random_attribute: 'socks' } }
      it 'raises an error' do
        expect {
          config.load_from_file(file)
        }.to raise_error(Hutch::UnknownAttributeError)
      end
    end

    context 'when attributes are valid' do
      let(:config_data) { { mq_host: host, mq_username: username } }

      it 'loads in the config data' do
        config.load_from_file(file)
        config.mq_host.should eq host
        config.mq_username.should eq username
      end
    end

    context 'when ruby code is interpolated in the yaml' do
      let(:config_data) { { mq_host: "<%= 'my host' %>" } }

      it 'correctly parses the code' do
        config.load_from_file(file)
        config.mq_host.should eq 'my host'
      end
    end
  end
end
