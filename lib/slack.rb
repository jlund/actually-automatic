module UpdateNotifier
  class Slack
    def self.notify(notification_message, config)
      request_body = { text: notification_message }

      config['webhook_urls'].each do |url|
        HTTParty.post(url, body: request_body.to_json)
      end
    end
  end
end
