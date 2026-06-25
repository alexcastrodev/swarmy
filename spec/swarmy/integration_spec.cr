require "../spec_helper"
require "../support/swarm_fixture"

Spec.after_suite { SwarmFixture.cleanup }

describe "Swarmy::Docker (integration)" do
  if SwarmFixture.ready?
    docker = Swarmy::Docker.new

    healthy_name = SwarmFixture.create_service("healthy", replicas: 1)
    failing_name = SwarmFixture.create_service(
      "failing", replicas: 1, command: ["sh", "-c", "exit 1"])

    it "lists only matching services via the substring filter" do
      services = docker.services(SwarmFixture.prefix)
      names = services.map(&.name)
      names.should contain(healthy_name)
      names.should contain(failing_name)
      names.all?(&.starts_with?(SwarmFixture.prefix)).should be_true
    end

    it "reports a created service with a parsed image and replica count" do
      svc = docker.services(SwarmFixture.prefix).find!(&.name.==(healthy_name))
      svc.image.should contain("busybox")
      svc.desired.should eq(1)
    end

    it "lists tasks for a created service" do
      tasks = docker.tasks(healthy_name)
      tasks.should_not be_empty
      tasks.all?(&.name.starts_with?(healthy_name)).should be_true
    end

    it "surfaces failing tasks for a crash-looping service" do
      tasks = [] of Swarmy::Task
      10.times do
        tasks = docker.tasks(failing_name)
        break if tasks.any?(&.failed?)
        sleep 1.second
      end
      tasks.any?(&.failed?).should be_true
    end
  else
    pending "requires an active Docker Swarm and the #{SwarmFixture::IMAGE} image"
  end
end
