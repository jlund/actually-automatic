require 'twilio-ruby'

module UpdateNotifier
  class SMS
    def self.notify(notification_message, config)
      if config['enabled']
        client = Twilio::REST::Client.new(config['twilio_account_sid'], config['twilio_auth_token'])

        config['recipients'].each do |recipient|
          client.messages.create(
            from: config['twilio_number'],
            to: recipient,
            body: notification_message
          )
        end
      end
    end
  end
end
