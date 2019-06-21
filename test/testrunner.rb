#!/usr/bin/env ruby
# typed: false

require 'find'
require 'open3'

module PlatinTest

# see https://stackoverflow.com/a/512505
module Abstract
  def abstract_methods(*args)
    args.each do |name|
      class_eval(<<-END, __FILE__, __LINE__)
        def #{name}(*args)
          raise NotImplementedError.new("You must implement #{name}.")
        end
      END
      # important that this END is capitalized, since it marks the end of <<-END
    end
  end
end

module Log
  ERROR = 0
  WARN  = 1
  INFO  = 2
  DEBUG = 3
  TRACE = 4

  @@level = INFO

  def self.set_level(val)
    @@level = val
  end

  def self.level
    @@level
  end

  def log(msg, level: INFO)
    if level <= @@level
      if level <= WARN
        STDERR.print msg
      else
        STDOUT.print msg
      end
    end
  end

  def logn(msg, level: INFO)
    log(msg + "\n", level: level)
  end

  def die(msg)
    log(msg, level: ERROR)
    exit(-1)
  end
end

class Test
  extend Abstract
  extend Log

  abstract_methods :enabled?, :run
  attr_accessor :path

  def to_s
    "'#{id}' (#{@path})"
  end

  def id
    File.basename(@path)
  end

  def result
    die("#{self.to_s}: No result found") if @result.nil?
    @result
  end

  def register_exception(exception)
    @result = Result.new(
      success: false,
      message: "Exception occured while running test: #{exception}",
      output: exception.backtrace.join("\n\t")
    )

  end

  def self.have_executable(cmd)
    cmd = cmd.gsub('\'', '')
    `command -v '#{cmd}'`
    $?.success?
  end

  def self.check_commands(*cmds)
    all_present = true
    cmds.each do |c|
      if have_executable(c).nil?
        logn("Command #{c} not found, skipping")
        all_present = false
      end
    end
    all_present
  end

  def self.check_gems(*gems)
    all_present = true
    gems.each do |g|
      begin
        require g
      rescue LoadError
        logn("Module '#{g}' not found'")
        all_present = false
      end
    end
    all_present
  end

  def self.execute_platin(cmd)
    logn("Running command '#{cmd}'", level: Log::DEBUG)
    output, status = Open3.capture2e(cmd)
    logn("Command exited with #{status}", level: Log::TRACE)
    logn(output, level: Log::TRACE)
    return output, status
  end

  def self.platin_getcycles(cmd)
    output, status = self.execute_platin(cmd)
    # match in reverse order: we want the last cycles
    cycles = output.lines.reverse.find {|l| l =~ /^\s+cycles: (-?\d+)/m}
    unless cycles.nil?
      return Integer($1), output, status.exitstatus
    else
      logn("Failed to determine cycle bound", level: Log::WARN)
      logn(output, level: Log::DEBUG)
      return nil, output, status.exitstatus
    end
  end
end

class Result
  attr_reader :success, :message, :output

  def success?
    @success
  end

  def initialize(success:, message:, output:)
    @success = success
    @message = message
    @output  = output
  end
end

class Runner
  extend Log

  def self.run(testdir:)
    tests            = collect_tests(testdir: testdir)
    active, disabled = tests.partition { |t| t.enabled? }

    disabled.map { |t| log("Disabled test #{t}: prerequisits not fulfilled\n") }
    active.map do |t|
      log("Running #{t}...")
      Dir.chdir(File.dirname(t.path)) do
        begin
          t.run
        rescue StandardError => e
          t.register_exception(e)
        end
      end
      if t.result.success?
        log(" passed\n")
      else
        log(" failed\n")
        log(t.result.message.to_s, level: Log::DEBUG)
        log(t.result.output.to_s, level: Log::TRACE)
      end
    end

    failed = active.reject { |t| t.result.success? }
    if failed.empty?
      log("All #{tests.length} tests passed successfully\n")
      success = 0
    else
      log("#{failed.length}/#{tests.length} failed:\n", level: Log::ERROR)
      failed.each do |t|
        log("#{t}: #{t.result.message}\n", level: Log::ERROR)
      end
      success = -1
    end

    logn("Summary: #{active.length - failed.length} passed," \
         " #{failed.length} failed" \
         " and #{disabled.length} skipped")

    success
  end

  def self.collect_tests(testdir: File.dirname(__FILE__))
    tests = []
    Find.find(testdir) do |path|
      if File.dirname(path) != File.dirname(__FILE__) &&
         FileTest.file?(path) &&
         File.basename(path) == "test.rb"
        begin
          # Object.new spawns a new namespace for eval
          test = Object.new.instance_eval(File.read(path))
          test.path = path
          tests << test
        rescue Exception => e
          die("Error occured while evaluating test '#{path}': #{e.class}: #{e.message}")
        end
      end
    end

    tests
  end
end
end

if __FILE__ == $PROGRAM_NAME
  require 'optparse'

  testdir = File.dirname(__FILE__)
  OptionParser.new do |opts|
    opts.banner = "Usage: testrunner.rb [options]"

    opts.on("-v", "--[no-]verbose", "Run verbosely (can be passed multiple times)") do |_|
      PlatinTest::Log::set_level(PlatinTest::Log::level + 1)
    end

    opts.on("-d", "--test-directory DIRECTORY", "Only run tests in the given directory") do |dir|
      testdir = dir
    end

    opts.on("-h", "--help", "Print this help") do
      puts opts
      exit 0
    end
  end.parse!
  exit PlatinTest::Runner::run(testdir: testdir)
end
