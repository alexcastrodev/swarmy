require "../spec_helper"

describe Tui::Width do
  describe ".width" do
    it "counts ascii as one column each" do
      Tui::Width.width("hello").should eq(5)
    end

    it "counts east asian wide characters as two columns" do
      Tui::Width.width("中文").should eq(4)
    end

    it "counts emoji as two columns" do
      Tui::Width.width("🚀").should eq(2)
    end

    it "counts combining marks as zero" do
      Tui::Width.width("é").should eq(1)
    end
  end

  describe ".visible" do
    it "ignores ansi escape codes" do
      Tui::Width.visible("\e[31mred\e[0m").should eq(3)
    end
  end

  describe ".pad" do
    it "pads to the target visible width" do
      Tui::Width.pad("ab", 5).should eq("ab   ")
    end

    it "accounts for wide characters when padding" do
      Tui::Width.width(Tui::Width.pad("中", 5)).should eq(5)
    end

    it "does not pad when already at or over width" do
      Tui::Width.pad("abcde", 3).should eq("abcde")
    end
  end

  describe ".truncate" do
    it "leaves short text untouched" do
      Tui::Width.truncate("short", 10).should eq("short")
    end

    it "truncates to the visible budget including the ellipsis" do
      result = Tui::Width.truncate("abcdefgh", 5)
      Tui::Width.width(result).should eq(5)
      result.should end_with("…")
    end

    it "never exceeds the budget with wide characters" do
      Tui::Width.width(Tui::Width.truncate("中文字符串", 5)).should be <= 5
    end
  end

  describe ".fit" do
    it "produces an exact visible width for short input" do
      Tui::Width.visible(Tui::Width.fit("ab", 6)).should eq(6)
    end

    it "produces an exact visible width for long input" do
      Tui::Width.visible(Tui::Width.fit("abcdefghij", 6)).should eq(6)
    end

    it "produces an exact visible width with wide chars" do
      Tui::Width.visible(Tui::Width.fit("中文名", 6)).should eq(6)
    end
  end
end
