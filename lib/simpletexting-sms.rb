module UpdateNotifier
  class SimpleTextingSMS
    def self.notify(notification_message, config)
      if config['enabled']
        campaign_title = config['campaign_title_prefix'].concat(" ", Date.today.to_s)

        request_headers = {
          "Authorization" => "Bearer #{config['api_key']}", 
          "Content-Type"  => "application/json"
        }

        request_body = {
          "title" => campaign_title,
          "listIds" => config['list_ids'],
          "accountPhone" => config['account_phone'],
          "messageTemplate" => {
            "mode" => "SINGLE_SMS_STRICTLY",
            "text" => notification_message,
            "unsubscribeText" => config['unsubscribe_text'].prepend("\n")
          }
        }

        HTTParty.post("https://api-app2.simpletexting.com/v2/api/campaigns",
                      headers: request_headers,
                      body: request_body.to_json)
      end
    end
  end
end
