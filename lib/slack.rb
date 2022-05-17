module UpdateNotifier
  class Slack
    def self.notify(notification_message, config)
      request_headers = { "Content-Type" => "application/json" }
      request_body    = { text: notification_message,
                          unfurl_links: true,
                          unfurl_media: true }

      config['webhook_urls'].each do |url|
        HTTParty.post(url, headers: request_headers, body: request_body.to_json)
      end
    end
  end
end
