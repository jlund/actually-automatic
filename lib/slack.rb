module UpdateNotifier
  class Slack
    def self.notify(notification_message, config)
      if config['enabled']
        post_hash = { text: notification_message }

        config['webhook_urls'].each do |url|
          HTTParty.post(url, body: post_hash.to_json)
        end
      end
    end
  end
end
