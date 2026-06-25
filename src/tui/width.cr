module Tui
  module Width
    extend self

    ANSI = /\e\[[0-9;?]*[a-zA-Z]/

    def visible(text : String) : Int32
      width(strip_ansi(text))
    end

    def width(text : String) : Int32
      total = 0
      text.each_char { |c| total += char_width(c) }
      total
    end

    def char_width(c : Char) : Int32
      code = c.ord
      return 0 if zero_width?(code)
      wide?(code) ? 2 : 1
    end

    def pad(text : String, target : Int32) : String
      gap = target - visible(text)
      return text if gap <= 0
      text + " " * gap
    end

    def truncate(text : String, max : Int32, ellipsis : String = "…") : String
      return text if width(text) <= max
      ell = width(ellipsis)
      budget = max - ell
      return ellipsis[0, max] if budget <= 0

      acc = 0
      String.build do |io|
        text.each_char do |c|
          w = char_width(c)
          break if acc + w > budget
          io << c
          acc += w
        end
        io << ellipsis
      end
    end

    def fit(text : String, target : Int32) : String
      pad(truncate(text, target), target)
    end

    def strip_ansi(text : String) : String
      text.gsub(ANSI, "")
    end

    def clamp_ansi(text : String, max : Int32) : String
      return text if visible(text) <= max
      acc = 0
      had_ansi = false
      chars = text.chars
      result = String.build do |io|
        i = 0
        while i < chars.size
          if chars[i] == '\e' && i + 1 < chars.size && chars[i + 1] == '['
            j = i + 2
            while j < chars.size && !chars[j].ascii_letter?
              j += 1
            end
            j += 1 if j < chars.size
            (i...j).each { |k| io << chars[k] }
            had_ansi = true
            i = j
            next
          end
          w = char_width(chars[i])
          break if acc + w > max
          io << chars[i]
          acc += w
          i += 1
        end
      end
      had_ansi ? result + "\e[0m" : result
    end

    private def zero_width?(code : Int32) : Bool
      return true if code == 0
      (code >= 0x0300 && code <= 0x036F) ||
        (code >= 0x200B && code <= 0x200F) ||
        (code >= 0xFE00 && code <= 0xFE0F) ||
        code == 0x00AD
    end

    private def wide?(code : Int32) : Bool
      (code >= 0x1100 && code <= 0x115F) ||
        code == 0x2329 || code == 0x232A ||
        (code >= 0x2E80 && code <= 0x303E) ||
        (code >= 0x3041 && code <= 0x33FF) ||
        (code >= 0x3400 && code <= 0x4DBF) ||
        (code >= 0x4E00 && code <= 0x9FFF) ||
        (code >= 0xA000 && code <= 0xA4CF) ||
        (code >= 0xAC00 && code <= 0xD7A3) ||
        (code >= 0xF900 && code <= 0xFAFF) ||
        (code >= 0xFE30 && code <= 0xFE4F) ||
        (code >= 0xFF00 && code <= 0xFF60) ||
        (code >= 0xFFE0 && code <= 0xFFE6) ||
        (code >= 0x1F300 && code <= 0x1FAFF) ||
        (code >= 0x20000 && code <= 0x3FFFD)
    end
  end
end
