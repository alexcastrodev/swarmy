require "../../src/swarmy/docker"

# Test harness that creates and tears down its OWN swarm services so the
# integration specs never read, touch, or depend on the user's real
# stacks. Every service it creates is namespaced under a unique prefix
# (see `PREFIX`) and removed again in `cleanup`.
#
# All fixtures are created with `--detach=true` and a lightweight local
# image so the suite stays fast and needs no network access.
module SwarmFixture
  # Smallest practical fixture image. `scratch` cannot be used here: it is
  # an empty image with no executable, so a service built on it never
  # starts. `busybox` (~6 MB) is the minimal image that actually runs a
  # command. Kept as a single constant so it is trivial to change.
  IMAGE = "busybox:latest"

  # Default command for a "healthy" fixture. busybox exits immediately
  # with no command, so a long sleep keeps the container alive and the
  # service in a running state.
  HEALTHY_COMMAND = ["sleep", "3600"]

  # Prefix that uniquely scopes everything this run creates. The PID keeps
  # parallel/leftover runs from colliding, and the literal "swarmy_test_"
  # makes stray fixtures obvious and easy to clean up by hand.
  class_getter prefix : String = "swarmy_test_#{Process.pid}_"

  # Names of services this process created, so cleanup only ever removes
  # its own fixtures.
  @@created = [] of String

  # True when a swarm is available to run integration specs against.
  # Specs should `pending`/skip (not fail) when this is false.
  def self.swarm_available? : Bool
    return @@swarm_available.not_nil! unless @@swarm_available.nil?
    state = capture("docker", ["info", "--format", "{{.Swarm.LocalNodeState}}"])
    @@swarm_available = state.try(&.strip) == "active"
  end

  @@swarm_available : Bool? = nil

  # True when the lightweight fixture image is present locally, so the
  # suite never triggers a network pull.
  def self.image_available? : Bool
    ids = capture("docker", ["images", "-q", IMAGE])
    !ids.nil? && !ids.strip.empty?
  end

  # Whether integration specs can run at all.
  def self.ready? : Bool
    swarm_available? && image_available?
  end

  # Creates a replicated test service and returns its full (prefixed)
  # name. `suffix` distinguishes services within one run. When no command
  # is given the service runs `HEALTHY_COMMAND` so it stays up.
  def self.create_service(suffix : String, replicas : Int32 = 1, command : Array(String)? = nil) : String
    name = "#{prefix}#{suffix}"
    args = [
      "service", "create",
      "--detach=true",
      "--name", name,
      "--replicas", replicas.to_s,
      IMAGE,
    ]
    args.concat(command || HEALTHY_COMMAND)
    run!("docker", args)
    @@created << name
    name
  end

  # Removes every service this process created. Safe to call multiple
  # times and never raises — teardown must not mask test failures.
  def self.cleanup
    @@created.each do |name|
      Process.run("docker", ["service", "rm", name],
        output: Process::Redirect::Close,
        error: Process::Redirect::Close)
    end
    @@created.clear
  end

  # --- low-level helpers ---------------------------------------------

  private def self.run!(cmd : String, args : Array(String))
    err = IO::Memory.new
    status = Process.run(cmd, args,
      output: Process::Redirect::Close, error: err)
    unless status.success?
      raise "#{cmd} #{args.join(' ')} failed: #{err.to_s.strip}"
    end
  end

  private def self.capture(cmd : String, args : Array(String)) : String?
    buffer = IO::Memory.new
    status = Process.run(cmd, args,
      output: buffer, error: Process::Redirect::Close)
    return nil unless status.success?
    buffer.to_s
  rescue File::NotFoundError
    nil
  end
end
