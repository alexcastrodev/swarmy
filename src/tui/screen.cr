module Tui
  class Screen
    CLEAR       = "\e[2J\e[H"
    HIDE_CURSOR = "\e[?25l"
    SHOW_CURSOR = "\e[?25h"
    CTRL_C      = '\u0003'

    {% if flag?(:darwin) %}
      TIOCGWINSZ = 0x40087468_u64
    {% else %}
      TIOCGWINSZ = 0x5413_u64
    {% end %}

    # Respect the LibC Struct alignment
    @[Packed]
    struct Winsize
      property row : LibC::UShort = 0
      property col : LibC::UShort = 0
      property xpixel : LibC::UShort = 0
      property ypixel : LibC::UShort = 0
    end

    lib LibIoctl
      fun ioctl(fd : LibC::Int, request : LibC::ULong, ...) : LibC::Int
    end

    def self.columns(fallback : Int32 = 80) : Int32
      cols = ENV["COLUMNS"]?.try(&.to_i?)
      return cols if cols && cols > 0
      detected = detect_columns
      return detected if detected > 0
      fallback
    end

    def self.detect_columns : Int32
      {STDOUT.fd, STDERR.fd, STDIN.fd}.each do |fd|
        ws = Winsize.new
        if LibIoctl.ioctl(fd, TIOCGWINSZ.to_u64, pointerof(ws).as(Void*)) == 0 && ws.col > 0
          return ws.col.to_i
        end
      end
      0
    rescue
      0
    end

    def clear
      print CLEAR
    end

    def hide_cursor
      print HIDE_CURSOR
    end

    def show_cursor
      print SHOW_CURSOR
    end

    def session(&)
      if STDIN.tty?
        STDIN.raw do
          enable_opost
          hide_cursor
          begin
            yield
          ensure
            show_cursor
            clear
          end
        end
      else
        yield
      end
    end

    def suspend(&)
      show_cursor
      clear
      STDIN.cooked do
        yield
      end
      enable_opost
      hide_cursor
    end

    private def enable_opost
      termios = uninitialized LibC::Termios
      return unless LibC.tcgetattr(STDOUT.fd, pointerof(termios)) == 0
      termios.c_oflag |= LibC::OPOST
      LibC.tcsetattr(STDOUT.fd, LibC::TCSANOW, pointerof(termios))
    end

    def read_key : Symbol
      c = STDIN.read_char
      return :quit if c.nil?

      case c
      when CTRL_C
        :quit
      when '\r', '\n'
        :enter
      when '\e'
        read_escape
      when 'k' then :up
      when 'j' then :down
      when 'h' then :left
      when 'l' then :right
      when 'q' then :q
      when 'r' then :r
      when 'b' then :b
      when 'e' then :e
      else          :unknown
      end
    end

    private def read_escape : Symbol
      STDIN.read_timeout = 50.milliseconds
      begin
        c = STDIN.read_char
      rescue IO::TimeoutError
        return :escape
      ensure
        STDIN.read_timeout = nil
      end
      return :escape if c.nil? || c != '['
      case STDIN.read_char
      when 'A' then :up
      when 'B' then :down
      when 'C' then :right
      when 'D' then :left
      else          :unknown
      end
    end
  end
end
