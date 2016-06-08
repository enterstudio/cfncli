require 'cfncli/cfn_client'
require 'cfncli/stack'
require 'cfncli/logger'
require 'cfncli/event_poller'

require 'waiting'
require 'pp'

module CfnCli
  class CloudFormation
    include CfnClient
    include Loggable

    def initialize
    end

    # Creates a stack and wait for the creation to be finished
    # @param options [Hash] Options for the stack creation
    #                       (@see http://docs.aws.amazon.com/sdkforruby/api/Aws/CloudFormation/Client.html)
    def create_stack(options, config = nil)
      create_or_update_stack(options, config)
    end

    # Creates a stack if it doesn't exist otherwise update it
    def create_or_update_stack(options, config = nil)
      opts = process_params(options.dup)

      stack_name = opts['stack_name']
      stack = create_stack_obj(stack_name, config)

      if stack.exists?
        stack.update(opts)
      else
        stack.create(opts)
      end

      stack
    end

    # Creates or update the stack and list events
    def apply_and_list_events(options, config = nil)
      # Create/update the stack
      logger.debug "Creating stack #{options['stack_name']}"
      stack = create_or_update_stack(options, config)

      events(stack.stack_id, config)
      Waiting.wait(interval: config.interval || default_config.interval, max_attempts: config.retries || default_config.retries) do |waiter|
        waiter.done if stack.finished?
      end  
    end

    # List stack events
    def events(stack_or_name, config = nil, reset_events = true, poller = nil, streamer = nil)
      stack = stack_or_name
      stack = create_stack_obj(stack_or_name, config) unless stack_or_name.is_a? CfnCli::Stack

      poller ||= EventPoller.new
      streamer ||= EventStreamer.new(stack, config)

      streamer.reset_events if reset_events

      logger.debug "Listing events for stack #{stack.stack_name}"
      stack.list_events(poller, streamer, config)
    end

    # Delete a stack
    def delete_stack(options, config)
      stack = create_stack_obj(options['stack_name'], config)
      options['stack_name'] = stack.stack_id
      stack.delete(options, config)
      events(stack.stack_id, config)
    end

    # Returns the stack status
    def stack_successful?(stack_name)
      Stack.new(stack_name).succeeded?
    end

    # Converts the 'standard' json stack parameters format to the format
    # expected by the API
    # (see https://blogs.aws.amazon.com/application-management/post/Tx1A23GYVMVFKFD/Passing-Parameters-to-CloudFormation-Stacks-with-the-AWS-CLI-and-Powershell)
    def self.parse_json_params(params)
      params.map do |param|
        {
          parameter_key: param.first.first,
          parameter_value: param.first.last
        }
      end
    end

    def default_config
      Config::CfnClient.new
    end

    private

    # Creates a new stack object
    # Mainly useful to mock it in unit tests
    def create_stack_obj(stack_name, config)
      stack = CfnCli::Stack.new(stack_name, config)
      stack.fetch_stack_id if stack.exists?
      stack
    end

    # Process the parameters
    def process_params(opts)
      opts.delete('disable_rollback')
      opts
    end
  end
end
