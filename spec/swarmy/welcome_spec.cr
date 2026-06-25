require "../spec_helper"

describe Swarmy::Welcome do
  describe "ITEMS" do
    it "offers browsing services and quitting" do
      actions = Swarmy::Welcome::ITEMS.map(&.action)
      actions.should eq([:services, :quit])
    end

    it "gives every item a label and a hint" do
      Swarmy::Welcome::ITEMS.each do |item|
        item.label.should_not be_empty
        item.hint.should_not be_empty
      end
    end
  end

  describe "#run" do
    it "falls back to browsing services when stdin is not a tty" do
      Swarmy::Welcome.new.run.should eq(:services)
    end
  end
end
