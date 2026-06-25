require "../tui"
require "./theme"

module Swarmy
  class Welcome
    LOGO = [
      "                                                         ",
      "   ███████ ██     ██  █████  ██████  ███    ███ ██    ██ ",
      "   ██      ██     ██ ██   ██ ██   ██ ████  ████  ██  ██  ",
      "   ███████ ██  █  ██ ███████ ██████  ██ ████ ██   ████   ",
      "        ██ ██ ███ ██ ██   ██ ██   ██ ██  ██  ██    ██    ",
      "   ███████  ███ ███  ██   ██ ██   ██ ██      ██    ██    ",
    ]

    record Item, label : String, hint : String, action : Symbol

    ITEMS = [
      Item.new("Browse services", "View and inspect swarm services", :services),
      Item.new("Quit", "Exit swarmy", :quit),
    ]

    def initialize(@screen : Tui::Screen = Tui::Screen.new)
      @cursor = 0
    end

    def run : Symbol
      return :services unless STDIN.tty?

      action = :quit
      @screen.session do
        loop do
          render
          case @screen.read_key
          when :up        then move(-1)
          when :down      then move(1)
          when :enter
            action = ITEMS[@cursor].action
            break
          when :q, :quit, :escape
            action = :quit
            break
          end
        end
      end
      action
    end

    private def move(delta : Int32)
      @cursor = (@cursor + delta) % ITEMS.size
    end

    private def render
      width = Tui::Screen.columns
      @screen.clear
      puts
      LOGO.each do |line|
        puts center(Tui::Colors.paint(line, Theme::TITLE), width)
      end
      puts
      puts center(Tui::Colors.paint("manage Docker Swarm services", Theme::HINT), width)
      puts
      puts

      lines = ITEMS.map_with_index { |item, i| menu_line(item, selected: i == @cursor) }
      max_w = lines.max_of { |l| Tui::Width.visible(l) }
      pad = ((width - max_w) // 2).clamp(0, width)
      lines.each { |l| puts (" " * pad) + l }

      puts
      puts
      puts center(footer, width)
    end

    private def menu_line(item : Item, selected : Bool) : String
      marker = selected ? "▸ " : "  "
      label =
        if selected
          Tui::Colors.paint("#{marker}#{item.label}", Theme::SELECTED)
        else
          Tui::Colors.paint(marker, Theme::KEY) + Tui::Colors.paint(item.label, Theme::VALUE)
        end
      label + "  " + Tui::Colors.paint(item.hint, Theme::HINT)
    end

    private def footer : String
      keys = {
        "↑/↓" => "move",
        "↵"   => "select",
        "q"   => "quit",
      }
      parts = keys.map do |k, v|
        Tui::Colors.paint(k, Theme::KEY) + " " + Tui::Colors.paint(v, Theme::HINT)
      end
      parts.join(Tui::Colors.paint("   ", Theme::HINT))
    end

    private def center(text : String, width : Int32) : String
      visible = Tui::Width.visible(text)
      pad = ((width - visible) // 2).clamp(0, width)
      (" " * pad) + text
    end
  end
end
