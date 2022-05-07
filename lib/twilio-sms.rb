module UpdateNotifier
  class TwilioSMS
    def self.notify(notification_message, config)
      url = "https://api.twilio.com/2010-04-01/Accounts/#{config['twilio_account_sid']}/Messages.json"

      credentials = { username: config['twilio_account_sid'],
                      password: config['twilio_auth_token'] }

      config['recipients'].each do |recipient|
        post_body = { "To" => recipient,
                      "From" => config['twilio_number'],
                      "Body" => notification_message }

        HTTParty.post(url, body: post_body, basic_auth: credentials)
      end
    end
  end
end
