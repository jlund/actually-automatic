module UpdateNotifier
  class Discord
    def self.notify(notification_message, config)
      request_headers = { "Content-Type"  => "application/json" }
      request_body    = { content: notification_message }

      config['webhook_urls'].each do |url|
        HTTParty.post(url, headers: request_headers, body: request_body.to_json)
      end
    end
  end
end
