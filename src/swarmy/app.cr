require "../tui"
require "./views"
require "./docker"
require "./theme"

module Swarmy
  class App
    getter? quit = false

    def initialize(@docker : Docker, @filter : String? = nil)
      @screen = Tui::Screen.new
      @services = [] of Service
      @cursor = 0
    end

    def run
      reload
      if @services.empty?
        puts Tui::Colors.paint("No services found.", Theme::HINT)
        return
      end

      @screen.session do
        loop do
          render_list
          case @screen.read_key
          when :up    then move(-1)
          when :down  then move(1)
          when :enter
            show_detail(@services[@cursor]) unless @services.empty?
            break if @quit
          when :r     then reload
          when :escape then break
          when :quit
            @quit = true
            break
          end
        end
      end
    end

    private def reload
      @services = @docker.services(@filter)
      @cursor = @services.empty? ? 0 : @cursor.clamp(0, @services.size - 1)
    end

    private def move(delta : Int32)
      return if @services.empty?
      @cursor = (@cursor + delta).clamp(0, @services.size - 1)
    end

    private def render_list
      width = Tui::Screen.columns
      table = Views.table(@services, width)
      @screen.clear
      puts Tui::Colors.paint("swarmy", Theme::TITLE) +
        Tui::Colors.paint("  ·  #{@services.size} services", Theme::HINT)
      puts
      puts Tui::Width.clamp_ansi(Views.header(table), width)
      @services.each_with_index do |svc, i|
        puts Tui::Width.clamp_ansi(Views.service_row(table, svc, selected: i == @cursor), width)
      end
      puts
      puts footer
    end

    private def footer : String
      keys = {
        "↑/↓" => "move",
        "↵"   => "details",
        "r"   => "reload",
        "q"   => "quit",
      }
      parts = keys.map do |k, v|
        Tui::Colors.paint(k, Theme::KEY) + " " + Tui::Colors.paint(v, Theme::HINT)
      end
      parts.join(Tui::Colors.paint("   ", Theme::HINT))
    end

    private def show_detail(svc : Service)
      tasks =
        begin
          @docker.tasks(svc.name)
        rescue ex : Docker::Error
          @screen.clear
          puts Tui::Colors.paint("Could not load tasks: #{ex.message}", Theme::FAILED)
          [] of Task
        end

      running = tasks.select { |t| t.desired_state.downcase == "running" && !t.failed? }
      task_cursor = 0

      loop do
        @screen.clear
        puts Views.service_detail(svc, tasks, running, task_cursor, Tui::Screen.columns)
        puts
        puts detail_footer(running.empty?)

        case @screen.read_key
        when :up
          task_cursor = (task_cursor - 1).clamp(0, {running.size - 1, 0}.max) unless running.empty?
        when :down
          task_cursor = (task_cursor + 1).clamp(0, running.size - 1) unless running.empty?
        when :enter, :e
          exec_into_task(running[task_cursor]) unless running.empty?
        when :l
          show_logs(running[task_cursor]) unless running.empty?
          break if @quit
        when :b, :escape then break
        when :quit
          @quit = true
          break
        end
      end
    end

    private def detail_footer(no_tasks : Bool) : String
      keys = no_tasks ? {} of String => String : {"↑/↓" => "move", "↵" => "exec", "l" => "logs"}
      keys["b/esc"] = "back"
      parts = keys.map do |k, v|
        Tui::Colors.paint(k, Theme::KEY) + " " + Tui::Colors.paint(v, Theme::HINT)
      end
      parts.join(Tui::Colors.paint("   ", Theme::HINT))
    end

    private def show_logs(task : Task)
      container =
        begin
          @docker.container_id(task.id)
        rescue ex : Docker::Error
          @screen.clear
          puts Tui::Colors.paint("Could not find container: #{ex.message}", Theme::FAILED)
          @screen.read_key
          return
        end

      if container.empty?
        @screen.clear
        puts Tui::Colors.paint("No container found for this task.", Theme::FAILED)
        @screen.read_key
        return
      end

      @screen.suspend do
        Process.run("docker", ["logs", "--tail", "100", "--follow", container],
          input: Process::Redirect::Inherit,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit)
      end
    end

    private def exec_into_task(task : Task)
      container =
        begin
          @docker.container_id(task.id)
        rescue ex : Docker::Error
          @screen.clear
          puts Tui::Colors.paint("Could not find container: #{ex.message}", Theme::FAILED)
          @screen.read_key
          return
        end

      if container.empty?
        @screen.clear
        puts Tui::Colors.paint("No container found for this task.", Theme::FAILED)
        @screen.read_key
        return
      end

      shell = select_shell
      return if shell.nil?

      @screen.suspend do
        status = Process.run("docker", ["exec", "-it", container, shell],
          input: Process::Redirect::Inherit,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit)
        unless status.success?
          puts Tui::Colors.paint("Shell exited with status #{status.exit_code}", Theme::FAILED)
          puts "Press any key to continue..."
          STDIN.read_char
        end
      end
    end

    SHELLS = ["/bin/bash", "/bin/sh"]

    private def select_shell : String?
      cursor = 0
      loop do
        @screen.clear
        puts Tui::Colors.paint("Select shell", Theme::TITLE)
        puts
        SHELLS.each_with_index do |sh, i|
          marker = i == cursor ? "▸ " : "  "
          if i == cursor
            puts Tui::Colors.paint("#{marker}#{sh}", Theme::SELECTED)
          else
            puts "  " + Tui::Colors.paint(sh, Theme::VALUE)
          end
        end
        puts
        puts Tui::Colors.paint("↵", Theme::KEY) + " " +
          Tui::Colors.paint("select", Theme::HINT) + "   " +
          Tui::Colors.paint("esc", Theme::KEY) + " " +
          Tui::Colors.paint("cancel", Theme::HINT)

        case @screen.read_key
        when :up   then cursor = (cursor - 1).clamp(0, SHELLS.size - 1)
        when :down then cursor = (cursor + 1).clamp(0, SHELLS.size - 1)
        when :enter then return SHELLS[cursor]
        when :escape then return nil
        when :quit
          @quit = true
          return nil
        end
      end
    end
  end
end
