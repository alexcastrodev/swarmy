require "../tui"
require "./models"

module Swarmy
  module Theme
    extend self

    TITLE    = "#{Tui::Colors::BOLD}#{Tui::Colors::WHITE}"
    HINT     = Tui::Colors::DIM
    LABEL    = Tui::Colors::GREY
    KEY      = Tui::Colors::CYAN
    VALUE    = Tui::Colors::WHITE
    PORT     = Tui::Colors::MAGENTA
    IMAGE    = Tui::Colors::BLUE
    HEADER   = "#{Tui::Colors::BOLD}#{Tui::Colors::CYAN}"
    SELECTED = "#{Tui::Colors::BOLD}#{Tui::Colors::BG_BLUE}#{Tui::Colors::WHITE}"

    HEALTHY  = Tui::Colors::GREEN
    DEGRADED = Tui::Colors::YELLOW
    FAILED   = Tui::Colors::RED
    NEUTRAL  = Tui::Colors::WHITE

    def health_color(health : Service::Health) : String
      case health
      in Service::Health::Healthy  then HEALTHY
      in Service::Health::Degraded then DEGRADED
      in Service::Health::Failed   then FAILED
      in Service::Health::Unknown  then NEUTRAL
      end
    end

    def health_symbol(health : Service::Health) : String
      case health
      in Service::Health::Healthy  then "●"
      in Service::Health::Degraded then "◐"
      in Service::Health::Failed   then "○"
      in Service::Health::Unknown  then "·"
      end
    end
  end
end
