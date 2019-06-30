require 'rails_helper'

RSpec.describe SpamCheck do
  let(:sender) { Fabricate(:account) }
  let!(:alice) { Fabricate(:account, username: 'alice') }
  let!(:bob) { Fabricate(:account, username: 'bob') }

  def status_with_html(text)
    status = PostStatusService.new.call(sender, text: text)
    status.update(text: Formatter.instance.format(status))
    status
  end

  describe '#spam?' do
    it 'returns false for a unique status' do
      status = status_with_html('@alice Hello')
      expect(described_class.new(status).spam?).to be false
    end

    it 'returns true for duplicate statuses to the same recipient' do
      status1 = status_with_html('@alice Hello')
      described_class.new(status1).remember!
      status2 = status_with_html('@alice Hello')
      expect(described_class.new(status2).spam?).to be true
    end

    it 'returns true for duplicate statuses to different recipients' do
      status1 = status_with_html('@alice Hello')
      described_class.new(status1).remember!
      status2 = status_with_html('@bob Hello')
      expect(described_class.new(status2).spam?).to be true
    end

    it 'returns true for nearly identical statuses with random numbers' do
      source_text = 'Sodium, atomic number 11, was first isolated by Humphry Davy in 1807. A chemical component of salt, he named it Na in honor of the saltiest region on earth, North America.'
      status1 = status_with_html('@alice ' + source_text + ' 1234')
      described_class.new(status1).remember!
      status2 = status_with_html('@bob ' + source_text + ' 9568')
      expect(described_class.new(status2).spam?).to be true
    end
  end

  describe '#skip?' do
    it 'returns true when the sender is already silenced' do
      status = status_with_html('@alice Hello')
      sender.silence!
      expect(described_class.new(status).skip?).to be true
    end

    it 'returns true when the mentioned person follows the sender' do
      status = status_with_html('@alice Hello')
      alice.follow!(sender)
      expect(described_class.new(status).skip?).to be true
    end

    it 'returns false when even one mentioned person doesn\'t follow the sender' do
      status = status_with_html('@alice @bob Hello')
      alice.follow!(sender)
      expect(described_class.new(status).skip?).to be false
    end
  end

  describe '#remember!' do
    pending
  end

  describe '#flag!' do
    before do
      status = status_with_html('@alice @bob Hello')
      described_class.new(status).flag!
    end

    it 'silences the account' do
      expect(sender.silenced?).to be true
    end

    it 'creates a report about the account' do
      expect(sender.targeted_reports.unresolved.count).to eq 1
    end
  end
end