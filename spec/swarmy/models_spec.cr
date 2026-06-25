require "../spec_helper"

describe Swarmy::Service do
  describe ".parse_replicas" do
    it "parses a simple running/desired string" do
      Swarmy::Service.parse_replicas("2/3").should eq({2, 3})
    end

    it "ignores trailing annotations" do
      Swarmy::Service.parse_replicas("0/1 (max 1 per node)").should eq({0, 1})
    end

    it "defaults to zero on garbage input" do
      Swarmy::Service.parse_replicas("oops").should eq({0, 0})
    end
  end

  describe "#health" do
    it "is healthy when running meets desired" do
      Swarmy::Service.new("id", "web", "replicated", "nginx", "", 3, 3)
        .health.should eq(Swarmy::Service::Health::Healthy)
    end

    it "is degraded when partially running" do
      Swarmy::Service.new("id", "web", "replicated", "nginx", "", 1, 3)
        .health.should eq(Swarmy::Service::Health::Degraded)
    end

    it "is failed when nothing is running but some is desired" do
      Swarmy::Service.new("id", "web", "replicated", "nginx", "", 0, 3)
        .health.should eq(Swarmy::Service::Health::Failed)
    end

    it "is unknown when nothing is desired" do
      Swarmy::Service.new("id", "web", "replicated", "nginx", "", 0, 0)
        .health.should eq(Swarmy::Service::Health::Unknown)
    end
  end

  describe ".from_docker_json" do
    it "builds a service from a docker json line" do
      json = %({"ID":"abc","Name":"api","Mode":"replicated","Image":"nginx:latest","Ports":"*:80->80/tcp","Replicas":"2/2"})
      svc = Swarmy::Service.from_docker_json(json)
      svc.name.should eq("api")
      svc.image.should eq("nginx:latest")
      svc.running.should eq(2)
      svc.desired.should eq(2)
      svc.health.should eq(Swarmy::Service::Health::Healthy)
    end
  end
end

describe Swarmy::Task do
  describe ".from_docker_json" do
    it "captures the error reason" do
      json = %({"ID":"t1","Name":"api.1","Node":"node-1","DesiredState":"Running","CurrentState":"Failed 2 minutes ago","Error":"task: non-zero exit (1)"})
      task = Swarmy::Task.from_docker_json(json)
      task.node.should eq("node-1")
      task.error.should eq("task: non-zero exit (1)")
      task.failed?.should be_true
    end

    it "is not failed for a running task" do
      json = %({"ID":"t1","Name":"api.1","Node":"node-1","DesiredState":"Running","CurrentState":"Running 5 minutes ago","Error":""})
      Swarmy::Task.from_docker_json(json).failed?.should be_false
    end
  end
end
