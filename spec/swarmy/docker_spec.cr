require "../spec_helper"

describe Swarmy::Docker do
  describe ".parse_services" do
    it "parses multiple json lines" do
      output = <<-OUT
        {"ID":"a","Name":"web","Mode":"replicated","Image":"nginx","Ports":"","Replicas":"1/1"}
        {"ID":"b","Name":"db","Mode":"replicated","Image":"postgres","Ports":"","Replicas":"0/1"}
        OUT
      services = Swarmy::Docker.parse_services(output)
      services.size.should eq(2)
      services.map(&.name).should eq(["web", "db"])
      services[1].health.should eq(Swarmy::Service::Health::Failed)
    end

    it "skips blank lines" do
      output = "\n\n{\"ID\":\"a\",\"Name\":\"web\",\"Replicas\":\"1/1\"}\n\n"
      Swarmy::Docker.parse_services(output).size.should eq(1)
    end

    it "returns an empty array for empty output" do
      Swarmy::Docker.parse_services("").should be_empty
    end
  end

  describe ".filter_services" do
    services = [
      Swarmy::Service.new("a", "hermes_kafka_kafka", "replicated", "kafka", "", 1, 1),
      Swarmy::Service.new("b", "hermes_infra_redis", "replicated", "redis", "", 1, 1),
    ]

    it "matches a substring anywhere in the name" do
      Swarmy::Docker.filter_services(services, "kafka").map(&.name)
        .should eq(["hermes_kafka_kafka"])
    end

    it "is case-insensitive" do
      Swarmy::Docker.filter_services(services, "REDIS").size.should eq(1)
    end

    it "returns everything for a nil or blank filter" do
      Swarmy::Docker.filter_services(services, nil).size.should eq(2)
      Swarmy::Docker.filter_services(services, "").size.should eq(2)
    end
  end

  describe ".parse_tasks" do
    it "parses task lines and finds failures" do
      output = <<-OUT
        {"ID":"t1","Name":"web.1","Node":"n1","DesiredState":"Running","CurrentState":"Running","Error":""}
        {"ID":"t2","Name":"web.1","Node":"n1","DesiredState":"Shutdown","CurrentState":"Failed","Error":"oom killed"}
        OUT
      tasks = Swarmy::Docker.parse_tasks(output)
      tasks.size.should eq(2)
      tasks.select(&.failed?).map(&.error).should eq(["oom killed"])
    end
  end
end
