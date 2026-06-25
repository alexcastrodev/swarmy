module Tui
  module Colors
    RESET = "\e[0m"
    BOLD  = "\e[1m"
    DIM   = "\e[2m"

    BLACK   = "\e[30m"
    RED     = "\e[31m"
    GREEN   = "\e[32m"
    YELLOW  = "\e[33m"
    BLUE    = "\e[34m"
    MAGENTA = "\e[35m"
    CYAN    = "\e[36m"
    WHITE   = "\e[37m"
    GREY    = "\e[90m"

    BG_BLUE = "\e[44m"
    BG_GREY = "\e[100m"

    def self.paint(text : String, *codes : String) : String
      return text unless enabled?
      "#{codes.join}#{text}#{RESET}"
    end

    @@enabled : Bool? = nil

    def self.enabled? : Bool
      cached = @@enabled
      return cached unless cached.nil?
      @@enabled = STDOUT.tty? && ENV["NO_COLOR"]?.nil?
    end

    def self.enabled=(value : Bool)
      @@enabled = value
    end
  end
end
