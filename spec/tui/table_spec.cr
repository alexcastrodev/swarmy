require "../spec_helper"

private def cols
  [
    Tui::Table::Column.new("NAME", min: 8, max: 40),
    Tui::Table::Column.new("REPLICAS", min: 8, max: 8),
    Tui::Table::Column.new("IMAGE", min: 10, flex: true),
    Tui::Table::Column.new("PORTS", min: 0),
  ]
end

private def sample_rows
  [
    ["web", "2/2", "nginx:1.25", "*:80->80"],
    ["a-much-longer-name", "0/3", "some/very-long-image:latest", "*:8080->8080"],
  ]
end

describe Tui::Table do
  describe ".fit" do
    it "sizes a fixed column to the widest cell (clamped)" do
      table = Tui::Table.fit(cols, sample_rows, 120, gutter: true)
      table.widths[0].should eq("a-much-longer-name".size)
    end

    it "never exceeds the terminal width when content fits" do
      [60, 80, 120, 200].each do |w|
        table = Tui::Table.fit(cols, sample_rows, w, gutter: true)
        table.total.should be <= w
      end
    end

    it "expands a flex column when there is room" do
      narrow = Tui::Table.fit(cols, sample_rows, 60, gutter: true)
      wide = Tui::Table.fit(cols, sample_rows, 200, gutter: true)
      wide.widths[2].should be > narrow.widths[2]
    end

    it "keeps columns at their minimums" do
      table = Tui::Table.fit(cols, sample_rows, 50, gutter: true)
      table.widths[2].should be >= 10
      table.widths[0].should be >= 8
    end

    it "handles an empty row set" do
      table = Tui::Table.fit(cols, [] of Array(String), 100, gutter: true)
      table.total.should be <= 100
    end
  end

  describe "#header and #row alignment" do
    it "aligns the header and every row to the same visible width" do
      table = Tui::Table.fit(cols, sample_rows, 100, gutter: true)
      header_w = Tui::Width.visible(table.header)
      sample_rows.each do |r|
        Tui::Width.visible(table.row(r, "●")).should eq(header_w)
      end
    end
  end
end
