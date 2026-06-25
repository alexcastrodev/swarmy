require "json"

module Swarmy
  struct Service
    getter id : String
    getter name : String
    getter mode : String
    getter image : String
    getter ports : String
    getter running : Int32
    getter desired : Int32

    def initialize(@id, @name, @mode, @image, @ports, @running, @desired)
    end

    def self.from_docker_json(raw : String) : Service
      j = JSON.parse(raw)
      running, desired = parse_replicas(j["Replicas"]?.try(&.as_s) || "0/0")
      new(
        id: j["ID"]?.try(&.as_s) || "",
        name: j["Name"]?.try(&.as_s) || "<unknown>",
        mode: j["Mode"]?.try(&.as_s) || "",
        image: j["Image"]?.try(&.as_s) || "",
        ports: j["Ports"]?.try(&.as_s) || "",
        running: running,
        desired: desired,
      )
    end

    def self.parse_replicas(text : String) : {Int32, Int32}
      head = text.split(' ', 2).first
      parts = head.split('/', 2)
      running = parts[0]?.try(&.to_i?) || 0
      desired = parts[1]?.try(&.to_i?) || 0
      {running, desired}
    end

    enum Health
      Healthy
      Degraded
      Failed
      Unknown
    end

    def health : Health
      return Health::Unknown if desired == 0
      return Health::Healthy if running >= desired
      return Health::Failed if running == 0
      Health::Degraded
    end

    def replicas : String
      "#{running}/#{desired}"
    end
  end

  struct Task
    getter id : String
    getter name : String
    getter node : String
    getter desired_state : String
    getter current_state : String
    getter error : String

    def initialize(@id, @name, @node, @desired_state, @current_state, @error)
    end

    def self.from_docker_json(raw : String) : Task
      j = JSON.parse(raw)
      new(
        id: j["ID"]?.try(&.as_s) || "",
        name: j["Name"]?.try(&.as_s) || "",
        node: j["Node"]?.try(&.as_s) || "",
        desired_state: j["DesiredState"]?.try(&.as_s) || "",
        current_state: j["CurrentState"]?.try(&.as_s) || "",
        error: j["Error"]?.try(&.as_s) || "",
      )
    end

    def failed? : Bool
      !error.empty? || current_state.downcase.starts_with?("failed")
    end
  end
end
