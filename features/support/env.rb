require 'simplecov'
SimpleCov.command_name 'tef-cucumber'

require 'open3'
require 'bunny'

# Used for #wait_for
require 'rspec/wait'
include RSpec::Wait

RSpec.configure do |config|
  config.wait_timeout = 120
end

# Common testing code
require 'tef/development'
World(TEF::Development)

require 'tef/development/testing/database'
TEF::Development::Testing.connect_to_test_db

require 'database_cleaner'
DatabaseCleaner.strategy = :truncation, {only: %w(keeper_dev_features keeper_dev_scenarios keeper_dev_test_suites tef_dev_tasks tef_dev_task_resources)}
DatabaseCleaner.start
DatabaseCleaner.clean


ENV['TEF_ENV'] ||= 'dev'
ENV['TEF_AMQP_URL_DEV'] ||= 'amqp://localhost:5672'


require 'tef'


Before do
  begin
    @tef_env = ENV['TEF_ENV'].downcase
    @bunny_url = ENV["TEF_AMQP_URL_#{@tef_env}"]

    @base_task = {type: 'task',
                  task_type: "generic"
    }

    @test_work_location = "#{File.dirname(__FILE__)}/../../testing"

    @bunny_connection = Bunny.new(@bunny_url)
    @bunny_connection.start
    @bunny_channel = @bunny_connection.create_channel
  rescue => e
    puts "caught before exception: #{e.message}"
    puts "trace: #{e.backtrace}"
    raise e
  end
end

Before do
  begin
    stdout, stderr, status = Open3.capture3('rabbitmqctl list_queues name')

    queue_list = stdout.split("\n")
    queue_list.delete('Listing queues ...')

    queue_list.each { |queue| delete_queue(queue) }
  rescue => e
    puts "Problem caught in Before hook: #{e.message}"
  end
end

After do
  kill_existing_tef_processes
  DatabaseCleaner.clean
end
