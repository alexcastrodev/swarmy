require "../tui"
require "./models"
require "./theme"

module Swarmy
  module Views
    extend self

    def columns : Array(Tui::Table::Column)
      [
        Tui::Table::Column.new("NAME", min: 8, max: 40),
        Tui::Table::Column.new("REPLICAS", min: 8, max: 8),
        Tui::Table::Column.new("IMAGE", min: 10, max: 40, color: Theme::IMAGE),
        Tui::Table::Column.new("PORTS", min: 0, color: Theme::PORT),
      ]
    end

    def table(services : Array(Service), term_width : Int32) : Tui::Table
      rows = services.map { |s| row_cells(s) }
      Tui::Table.fit(columns, rows, term_width, gutter: true)
    end

    def row_cells(svc : Service) : Array(String)
      [svc.name, svc.replicas, svc.image, svc.ports]
    end

    def header(table : Tui::Table) : String
      Tui::Colors.paint(table.header, Theme::HEADER)
    end

    def service_row(table : Tui::Table, svc : Service, selected : Bool) : String
      cells = row_cells(svc)
      hc = Theme.health_color(svc.health)

      if selected
        plain = table.row(cells, "▸")
        return Tui::Colors.paint(Tui::Width.strip_ansi(plain), Theme::SELECTED)
      end

      table.row(cells, Theme.health_symbol(svc.health), hc) do |cell, i|
        case i
        when 0 then Tui::Colors.paint(cell, hc, Tui::Colors::BOLD)
        when 1 then Tui::Colors.paint(cell, hc)
        when 2 then Tui::Colors.paint(cell, Theme::IMAGE)
        else        Tui::Colors.paint(cell, Theme::PORT)
        end
      end
    end

    def service_detail(svc : Service, tasks : Array(Task), running : Array(Task), task_cursor : Int32, width : Int32 = 60) : String
      rule = width.clamp(20, 100)
      String.build do |io|
        io << Tui::Colors.paint("Service: #{svc.name}", Theme::TITLE) << "\n"
        io << Tui::Colors.paint("─" * rule, Theme::LABEL) << "\n\n"

        io << field("ID", svc.id)
        io << field("Mode", svc.mode)
        io << field("Image", svc.image, Theme::IMAGE)
        io << field("Ports", svc.ports.empty? ? "—" : svc.ports, Theme::PORT)

        status_text = Tui::Colors.paint(
          "#{svc.replicas} (#{svc.health.to_s.downcase})",
          Theme.health_color(svc.health),
          Tui::Colors::BOLD,
        )
        io << Tui::Colors.paint(Tui::Width.fit("  Replicas", 14), Theme::KEY) << status_text << "\n\n"

        io << Tui::Colors.paint("Tasks", Theme::TITLE) << "\n"
        if tasks.empty?
          io << Tui::Colors.paint("  no tasks reported", Theme::HINT) << "\n"
        else
          tasks.each do |t|
            selected = running.any? { |r| r.id == t.id } && running.index { |r| r.id == t.id } == task_cursor
            io << task_row(t, width, selected: selected)
          end
        end

        failing = svc.health.healthy? ? [] of Task : tasks.select(&.failed?)
        unless failing.empty?
          io << "\n" << Tui::Colors.paint("Why it is not running", Theme::FAILED) << "\n"
          failing.each do |t|
            reason = t.error.empty? ? t.current_state : t.error
            io << "  " << Tui::Colors.paint("✗", Theme::FAILED) << " "
            io << Tui::Colors.paint(Tui::Width.truncate(reason, (width - 4).clamp(10, 200)), Theme::NEUTRAL) << "\n"
          end
        end
      end
    end

    private def task_row(t : Task, width : Int32, selected : Bool = false) : String
      color = t.failed? ? Theme::FAILED : Theme::HEALTHY
      name_w = (width // 3).clamp(12, 40)
      marker = selected ? "▸ " : "  "
      String.build do |io|
        if selected
          io << Tui::Colors.paint(
            "#{marker}#{Tui::Width.fit(t.name, name_w)} #{Tui::Width.fit(t.node, 14)} #{t.current_state}",
            Theme::SELECTED
          ) << "\n"
        else
          io << marker << Tui::Colors.paint("•", color) << " "
          io << Tui::Colors.paint(Tui::Width.fit(t.name, name_w), Theme::VALUE) << " "
          io << Tui::Colors.paint(Tui::Width.fit(t.node, 14), Theme::LABEL) << " "
          io << Tui::Colors.paint(t.current_state, color) << "\n"
        end
      end
    end

    private def field(key : String, value : String, value_color : String = Theme::VALUE) : String
      Tui::Colors.paint(Tui::Width.fit("  #{key}", 14), Theme::KEY) +
        Tui::Colors.paint(value.empty? ? "—" : value, value_color) + "\n"
    end
  end
end
