module UpdateNotifier
  class Signal
    def self.notify(notification_message, config)
      # `signal-cli` needs to periodically "receive" and process new
      # messages (such as incoming delivery receipts).
      system("#{config['signal_cli_executable']}", "-u", "#{config['account_phone']}", "receive")

      unless config['groups'].nil?
        config['groups'].each do |group|
          system("#{config['signal_cli_executable']}", "--trust-new-identities", "always", "-u", "#{config['account_phone']}", "send", "-m", "#{notification_message}", "-g", "#{group}")
        end
      end

      unless config['recipients'].nil?
        config['recipients'].each do |recipient|
          system("#{config['signal_cli_executable']}", "--trust-new-identities", "always", "-u", "#{config['account_phone']}", "send", "-m", "#{notification_message}", "#{recipient}")
        end
      end
    end
  end
end
