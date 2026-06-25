require "../spec_helper"

private def sample_services
  [
    Swarmy::Service.new("id", "web", "replicated", "nginx:1.25", "*:80->80", 2, 2),
    Swarmy::Service.new("id", "a-longer-service-name", "replicated", "some/image:latest", "", 0, 3),
    Swarmy::Service.new("id", "db", "replicated", "postgres:18", "*:5432->5432", 1, 1),
  ]
end

describe Swarmy::Views do
  describe ".service_row" do
    it "renders the service name, replicas and image" do
      services = sample_services
      table = Swarmy::Views.table(services, 120)
      row = Swarmy::Views.service_row(table, services.first, selected: false)
      row.should contain("web")
      row.should contain("2/2")
      row.should contain("nginx:1.25")
      row.should contain("*:80->80")
    end

    it "marks the selected row with a cursor glyph" do
      services = sample_services
      table = Swarmy::Views.table(services, 120)
      Swarmy::Views.service_row(table, services.first, selected: true).should contain("▸")
    end

    it "aligns the header and every row to the same visible width" do
      services = sample_services
      table = Swarmy::Views.table(services, 100)
      header_w = Tui::Width.visible(Swarmy::Views.header(table))
      services.each do |svc|
        Tui::Width.visible(Swarmy::Views.service_row(table, svc, selected: false))
          .should eq(header_w)
        Tui::Width.visible(Swarmy::Views.service_row(table, svc, selected: true))
          .should eq(header_w)
      end
    end

    it "stays within the terminal width on a narrow screen" do
      services = sample_services
      table = Swarmy::Views.table(services, 60)
      services.each do |svc|
        Tui::Width.visible(Swarmy::Views.service_row(table, svc, selected: false))
          .should be <= 60
      end
    end
  end

  describe ".service_detail" do
    it "shows why a service is not running" do
      svc = Swarmy::Service.new("id", "api", "replicated", "api:latest", "", 0, 1)
      tasks = [
        Swarmy::Task.new("t1", "api.1", "node-1", "Shutdown", "Failed", "no such image"),
      ]
      running = tasks.select { |t| t.desired_state.downcase == "running" && !t.failed? }
      detail = Swarmy::Views.service_detail(svc, tasks, running, 0)
      detail.should contain("Service: api")
      detail.should contain("Why it is not running")
      detail.should contain("no such image")
    end

    it "handles a healthy service with no failures" do
      svc = Swarmy::Service.new("id", "api", "replicated", "api:latest", "", 1, 1)
      tasks = [Swarmy::Task.new("t1", "api.1", "node-1", "Running", "Running", "")]
      running = tasks.select { |t| t.desired_state.downcase == "running" && !t.failed? }
      Swarmy::Views.service_detail(svc, tasks, running, 0).should_not contain("Why it is not running")
    end
  end
end

describe Swarmy::Theme do
  it "maps each health state to a distinct color" do
    colors = Swarmy::Service::Health.values.map { |h| Swarmy::Theme.health_color(h) }
    colors.uniq.size.should be >= 3
  end

  it "has a glyph for every health state" do
    Swarmy::Service::Health.values.each do |h|
      Swarmy::Theme.health_symbol(h).should_not be_empty
    end
  end
end
