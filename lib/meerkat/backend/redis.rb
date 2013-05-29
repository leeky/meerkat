require 'em-hiredis'

module Meerkat
  module Backend
    class Redis
      def initialize(redis_uri = nil)
        @subs = {}
        EM.next_tick do
          @sub = EM::Hiredis.connect redis_uri
          @pub = EM::Hiredis.connect redis_uri
          @sub.pubsub.on :pmessage do |topic, channel, message|
            @subs[topic].each { |cb| cb.call channel, message }
          end
        end
      end

      def publish(topic, json)
        @pub.pubsub.publish topic, json
      end

      def subscribe(topic, &callback)
        if @subs[topic]
          @subs[topic] << callback
        else
          @subs[topic] = [ callback ]
          EM.next_tick do
            @sub.pubsub.psubscribe topic
          end
        end
        [topic, callback]
      end

      def unsubscribe(sub)
        topic, cb = sub
        @subs[topic].delete cb
        if @subs[topic].empty?
          EM.next_tick do
            @subs.delete topic
            @sub.pubsub.punsubscribe(topic)
          end
        end
      end
    end
  end
end
