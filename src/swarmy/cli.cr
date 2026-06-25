require "option_parser"
require "../tui"
require "./docker"
require "./app"
require "./welcome"
require "./theme"

module Swarmy
  VERSION = "0.1.0"

  class CLI
    def initialize(@docker : Docker = Docker.new)
    end

    def run(argv : Array(String)) : Int32
      filter : String? = nil
      command : String? = nil
      early_exit : Int32? = nil

      parser = OptionParser.new do |p|
        p.banner = "swarmy — manage Docker Swarm services\n\nUsage: swarmy <command> [options]\n\nCommands:\n  services    Browse swarm services interactively\n\nOptions:"
        p.on("--filter NAME", "Filter services by name") { |v| filter = v }
        p.on("-v", "--version", "Show version") do
          puts "swarmy #{VERSION}"
          early_exit = 0
        end
        p.on("-h", "--help", "Show this help") do
          puts p
          early_exit = 0
        end
        p.unknown_args do |args|
          command = args.first?
        end
      end

      begin
        parser.parse(argv)
      rescue ex : OptionParser::Exception
        STDERR.puts Tui::Colors.paint(ex.message || "Invalid arguments", Theme::FAILED)
        STDERR.puts parser
        return 1
      end

      if code = early_exit
        return code
      end

      case command
      when nil
        welcome(filter)
      when "services"
        services(filter)
        0
      else
        STDERR.puts Tui::Colors.paint("Unknown command: #{command}", Theme::FAILED)
        STDERR.puts parser
        1
      end
    end

    private def welcome(filter : String?) : Int32
      loop do
        case Welcome.new.run
        when :services
          return 0 if services(filter)
        else
          return 0
        end
      end
    end

    private def services(filter : String?) : Bool
      app = App.new(@docker, filter)
      app.run
      app.quit?
    rescue ex : Docker::Error
      STDERR.puts Tui::Colors.paint("Docker error: #{ex.message}", Theme::FAILED)
      false
    end
  end
end
