require "./models"

module Swarmy
  class Docker
    class Error < Exception
    end

    def services(filter : String? = nil) : Array(Service)
      raw = run(["service", "ls", "--format", "{{json .}}"])
      services = Docker.parse_services(raw)
      Docker.filter_services(services, filter)
    end

    def self.filter_services(services : Array(Service), filter : String?) : Array(Service)
      return services if filter.nil? || filter.blank?
      needle = filter.downcase
      services.select { |svc| svc.name.downcase.includes?(needle) }
    end

    def tasks(service_name : String) : Array(Task)
      raw = run(["service", "ps", "--no-trunc", "--format", "{{json .}}", service_name])
      Docker.parse_tasks(raw)
    end

    def container_id(task_id : String) : String
      run(["inspect", "--format", "{{.Status.ContainerStatus.ContainerID}}", task_id]).strip
    end

    def self.parse_services(output : String) : Array(Service)
      parse_lines(output) { |line| Service.from_docker_json(line) }
    end

    def self.parse_tasks(output : String) : Array(Task)
      parse_lines(output) { |line| Task.from_docker_json(line) }
    end

    private def self.parse_lines(output : String, &block : String -> T) : Array(T) forall T
      result = [] of T
      output.each_line do |line|
        line = line.strip
        next if line.empty?
        result << block.call(line)
      end
      result
    end

    private def run(args : Array(String)) : String
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      status = Process.run("docker", args, output: stdout, error: stderr)
      unless status.success?
        msg = stderr.to_s.strip
        msg = "docker exited with status #{status.exit_code}" if msg.empty?
        raise Error.new(msg)
      end
      stdout.to_s
    rescue ex : File::NotFoundError
      raise Error.new("the `docker` command was not found on your PATH")
    end
  end
end
