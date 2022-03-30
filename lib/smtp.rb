require 'net/smtp'

module UpdateNotifier
  class SMTP
    def self.notify(notification_message, config)
      if config['enabled']
        smtp = Net::SMTP.new(config['server'], config['port'])

        if config['tls']
          smtp.enable_tls
        end

        email_headers = <<~HEADERS
        From: #{config['from_email']}
        Subject: #{config['subject']}
        HEADERS

        smtp.start(config['helo_domain'], config['auth_user'], config['auth_pass'], :login) do
          smtp.send_message(notification_message.prepend(email_headers),
                            config['from_email'],
                            config['bcc_recipients'])
        end
      end
    end
  end
end
