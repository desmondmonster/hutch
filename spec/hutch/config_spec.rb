require 'hutch/config'
require 'tempfile'

describe 'Configuration' do
  let(:new_value) { 'not-localhost' }

  describe '.get' do
    context 'for valid attributes' do
      subject { Hutch.config.get(:mq_host) }

      context 'with no overridden value' do
        it { should == 'localhost' }
      end

      context 'with an overridden value' do
        before  { Hutch.config.stub(user_config: { mq_host: new_value }) }
        it { should == new_value }
      end
    end

    context 'for invalid attributes' do
      let(:invalid_get) { ->{ Hutch.config.get(:invalid_attr) } }
      specify { invalid_get.should raise_error Hutch::UnknownAttributeError }
    end
  end

  describe '.set' do
    context 'for valid attributes' do
      before  { Hutch.config.set(:mq_host, new_value) }
      subject { Hutch.config.user_config[:mq_host] }

      context 'sets value in user config hash' do
        it { should == new_value }
      end
    end

    context 'for invalid attributes' do
      let(:invalid_set) { ->{ Hutch.config.set(:invalid_attr, new_value) } }
      specify { invalid_set.should raise_error Hutch::UnknownAttributeError }
    end
  end

  describe 'a magic getter' do
    context 'for a valid attribute' do
      it 'calls get' do
        Hutch.config.should_receive(:get).with(:mq_host)
        Hutch.config.mq_host
      end
    end

    context 'for an invalid attribute' do
      let(:invalid_getter) { ->{ Hutch.config.invalid_attr } }
      specify { invalid_getter.should raise_error NoMethodError }
    end
  end

  describe 'a magic setter' do
    context 'for a valid attribute' do
      it 'calls set' do
        Hutch.config.should_receive(:set).with(:mq_host, new_value)
        Hutch.config.mq_host = new_value
      end
    end

    context 'for an invalid attribute' do
      let(:invalid_setter) { ->{ Hutch.config.invalid_attr = new_value } }
      specify { invalid_setter.should raise_error NoMethodError }
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
          Hutch.config.load_from_file(file)
        }.to raise_error(NoMethodError)
      end
    end

    context 'when attributes are valid' do
      let(:config_data) { { mq_host: host, mq_username: username } }

      it 'loads in the config data' do
        Hutch.config.load_from_file(file)
        Hutch.config.mq_host.should eq host
        Hutch.config.mq_username.should eq username
      end
    end

    context 'when ruby code is interpolated in the yaml' do
      let(:config_data) { { mq_host: "<%= 'my host' %>" } }

      it 'correctly parses the code' do
        Hutch.config.load_from_file(file)
        Hutch.config.mq_host.should eq 'my host'
      end
    end
  end
end
