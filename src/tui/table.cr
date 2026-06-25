require "./width"
require "./colors"

module Tui
  class Table
    struct Column
      getter title : String
      getter min : Int32
      getter max : Int32
      getter flex : Bool
      getter color : String?

      def initialize(@title, @min = 0, @max = 1000, @flex = false, @color = nil)
      end
    end

    GAP    = 2
    GUTTER = 3

    getter columns : Array(Column)
    getter widths : Array(Int32)
    getter gutter : Bool

    def initialize(@columns : Array(Column), @widths : Array(Int32), @gutter : Bool)
    end

    def self.fit(columns : Array(Column), rows : Array(Array(String)), term_width : Int32, gutter : Bool = false) : Table
      desired = columns.map_with_index do |col, i|
        content = rows.map { |r| Width.visible(r[i]? || "") }.max? || 0
        [content, Width.visible(col.title), col.min].max.clamp(col.min, col.max)
      end

      lead = gutter ? GUTTER : 0
      gaps = GAP * (columns.size - 1)
      budget = (term_width - lead - gaps).clamp(columns.sum(&.min), Int32::MAX)

      flex_indices = columns.each_index.select { |i| columns[i].flex }.to_a
      widths = desired.dup

      if flex_indices.empty?
        shrink!(widths, columns, budget)
      else
        flex_indices.each { |i| widths[i] = columns[i].min }
        used = widths.sum
        slack = budget - used

        if slack >= 0
          share = slack // flex_indices.size
          flex_indices.each { |i| widths[i] = (columns[i].min + share).clamp(columns[i].min, columns[i].max) }
          leftover = budget - widths.sum
          grow_flex!(widths, columns, flex_indices, leftover) if leftover > 0
        else
          shrink!(widths, columns, budget)
        end
      end

      new(columns, widths, gutter)
    end

    private def self.grow_flex!(widths, columns, flex_indices, leftover)
      flex_indices.each do |i|
        break if leftover <= 0
        room = columns[i].max - widths[i]
        next if room <= 0
        add = Math.min(room, leftover)
        widths[i] += add
        leftover -= add
      end
    end

    private def self.shrink!(widths, columns, budget)
      overflow = widths.sum - budget
      return if overflow <= 0
      shrinkables = columns.each_index.select { |i| widths[i] > columns[i].min }.to_a
      until overflow <= 0 || shrinkables.empty?
        shrinkables.each do |i|
          break if overflow <= 0
          if widths[i] > columns[i].min
            widths[i] -= 1
            overflow -= 1
          end
        end
        shrinkables = shrinkables.select { |i| widths[i] > columns[i].min }
      end
    end

    def total : Int32
      lead = gutter ? GUTTER : 0
      lead + widths.sum + GAP * (columns.size - 1)
    end

    def header(glyph : String = "", glyph_color : String? = nil) : String
      render_cells(columns.map(&.title), glyph, glyph_color) { |cell, i| cell }
    end

    def row(cells : Array(String), glyph : String = "", glyph_color : String? = nil, &block : String, Int32 -> String) : String
      render_cells(cells, glyph, glyph_color, &block)
    end

    def row(cells : Array(String), glyph : String = "", glyph_color : String? = nil) : String
      render_cells(cells, glyph, glyph_color) do |cell, i|
        if color = columns[i].color
          Colors.paint(cell, color)
        else
          cell
        end
      end
    end

    private def render_cells(cells : Array(String), glyph : String, glyph_color : String?, &block : String, Int32 -> String) : String
      String.build do |io|
        io << render_gutter(glyph, glyph_color) if gutter
        columns.each_index do |i|
          io << " " * GAP if i > 0
          fitted = Width.fit(cells[i]? || "", widths[i])
          io << block.call(fitted, i)
        end
      end
    end

    private def render_gutter(glyph : String, glyph_color : String?) : String
      return " " * GUTTER if glyph.empty?
      symbol = glyph_color ? Colors.paint(glyph, glyph_color) : glyph
      pad = GUTTER - Width.visible(glyph)
      "#{symbol}#{" " * (pad < 0 ? 0 : pad)}"
    end
  end
end
