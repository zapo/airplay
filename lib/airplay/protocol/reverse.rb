require "celluloid"
require "net/ptth"
require "net/http"
require "airplay/protocol/app"

module Airplay::Protocol
  # Public: Handles the reverse connection
  #
  class Reverse
    include Celluloid

    attr_accessor :callbacks
    attr_reader   :state

    def initialize(node, purpose = "event")
      @ptth = Net::PTTH.new("http://#{node.address}")
      @ptth.set_debug_output = $stdout if ENV["HTTP_DEBUG"]
      @state = "disconnected"
      @purpose = purpose
      @ptth.app = Airplay.app

      @callbacks = []

      async.pipeline
      @ptth.app.pipeline = self.async
    end

    # Public: Disconnects the current connection
    #
    def disconnect
      @state = "disconnected"
      @ptth.close
    end

    # Public: Connects to the reverse resource and starts the switching
    #
    def connect
      request = Net::HTTP::Post.new("/reverse")
      request["X-Apple-Purpose"] = @purpose
      request["X-Apple-Session-ID"] = Airplay.session
      request["X-Apple-Device-ID"] = "0x581faa7c9754"

      @ptth.request(request)
      @state = "connected"
    end

    # Public: Pipelines all the incomming messages to the callback ppol
    #
    def pipeline
      loop do
        message = receive { |msg| msg.is_a? Message }
        @callbacks.each do |callback|
          callback.call(message.content)
        end
      end
    end
  end
end
