require "./swarmy/cli"

exit Swarmy::CLI.new.run(ARGV)
