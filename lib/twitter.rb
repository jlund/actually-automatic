require 'tweetkit'

module UpdateNotifier
  class Twitter
    def self.notify(notification_message, config)
      twitter_client = Tweetkit::Client.new do |t|
        t.consumer_key        = config['consumer_key']
        t.consumer_secret     = config['consumer_secret']
        t.access_token        = config['access_token']
        t.access_token_secret = config['access_token_secret']
      end

      twitter_client.post_tweet(text: notification_message)
    end
  end
end
