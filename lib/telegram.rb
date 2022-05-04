module UpdateNotifier
  class Telegram
    def self.notify(notification_message, config)
      if config['enabled']
        url = "https://api.telegram.org/bot#{config['token']}/sendMessage"
        request_headers = { "Content-Type"  => "application/json" }

        config['chat_ids'].each do |id|
          request_body = {
            chat_id: id,
            text: notification_message
          }

          HTTParty.post(url, headers: request_headers, body: request_body.to_json)
        end
      end
    end
  end
end
