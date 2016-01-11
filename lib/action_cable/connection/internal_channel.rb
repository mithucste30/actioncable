module ActionCable
  module Connection
    # Makes it possible for the RemoteConnection to disconnect a specific connection.
    module InternalChannel
      extend ActiveSupport::Concern

      private
        def internal_redis_channel
          "action_cable/#{connection_identifier}"
        end

        def subscribe_to_internal_channel
          if connection_identifier.present?
            callback = -> (message) { process_internal_message(message) }
            @_internal_redis_subscriptions ||= []
            @_internal_redis_subscriptions << [ internal_redis_channel, callback ]

            EM.next_tick { pubsub.subscribe(internal_redis_channel, &callback) }
            logger.info "Registered connection (#{connection_identifier})"
          end
        end

        def unsubscribe_from_internal_channel
          if @_internal_redis_subscriptions.present?
            @_internal_redis_subscriptions.each { |channel, callback| EM.next_tick { pubsub.unsubscribe_proc(channel, callback) } }
          end
        end

        def process_internal_message(message)
          message = ActiveSupport::JSON.decode(message)

          case message['type']
          when 'disconnect'
            logger.info "Removing connection (#{connection_identifier})"
            websocket.close
          end
        rescue Exception => e
          logger.error "There was an exception - #{e.class}(#{e.message})"
          logger.error e.backtrace.join("\n")

          close
        end
    end
  end
end
