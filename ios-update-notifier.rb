#!/usr/bin/env ruby

require 'bundler/setup'
require 'date'
require 'httparty'
require 'json'
require 'thor'
require 'yaml'
require_relative 'lib/slack.rb'
require_relative 'lib/sms.rb'
require_relative 'lib/smtp.rb'

module UpdateNotifier
  class CLI < Thor

    desc "notify", "Send a notification if a new iOS update has been released since the last update was seen."
    long_desc <<-LONGDESC
      When the command is run for the first time, a new `LAST_SEEN` file is created
      and the date of the initial execution is recorded. Notifications are only
      sent if a new release is discovered with a posting date that is more recent
      than the value in the `LAST_SEEN` file.

      As a result (and by design!) the initial run will never trigger
      any notifications.

      During subsequent runs, notifications will be sent and the `LAST_SEEN` value
      will be modified to reflect the release date of the latest version whenever
      a new update is detected.

      To ensure timely notifications, running this command frequently (e.g. every
      45 minutes) is recommended. However, in the event that multiple updates get
      released between the most recent `LAST_SEEN` date and the current execution
      time, only one set of notifications will be sent (and only for the
      latest update).
    LONGDESC
    def notify
      latest_update = new_updates.max_by { |u| Gem::Version.new(u['ProductVersion']) }

      if latest_update.nil?
        puts "No new updates found."
      else
        puts "New update discovered: #{latest_update['ProductVersion']} -- Sending notifications."

        notification_text = config['notification_text'].gsub('$VERSION', latest_update['ProductVersion'])

        send_notifications(notification_text)

        update_last_seen(Date.parse(latest_update["PostingDate"]))
      end

      File.write("#{__dir__}/LAST_RUN", DateTime.now)
    end

    desc "test", "Send a test message to verify that notifications are configured correctly."
    option :message, required: true
    def test
      test_message = options[:message].chomp

      say("Config status:", :green)
      puts "  Slack enabled: #{config['slack']['enabled']}"
      puts "  SMS enabled: #{config['sms']['enabled']}"
      puts "  SMTP enabled: #{config['smtp']['enabled']}\n\n"

      say("Test message:", :green)
      puts "  #{test_message}\n\n"

      continue = ask("Would you like to continue?", limited_to: ["yes", "no"], default: "no")

      if continue == "yes"
        send_notifications(test_message)
      end
    end

    private

    def config
      config_file = "#{__dir__}/config.yml"

      if File.exists?(config_file)
        @config ||= YAML.load_file(config_file)
      else
        say("No config file found!", :red)
        puts "Copy the sample config and update it with your preferences."
        puts "  cp config.yml.sample config.yml && vim config.yml"
        exit(false)
      end
    end

    def last_seen
      if File.exists?(last_seen_file)
        return Date.parse(File.read(last_seen_file))
      else
        say("First run! Creating a new `LAST_SEEN` file.", :green)
        first_run_date = DateTime.now
        update_last_seen(first_run_date)
        return first_run_date
      end
    end

    def last_seen_file
      "#{__dir__}/LAST_SEEN"
    end

    def new_updates
      pmv["PublicAssetSets"]["iOS"].select do |k, v|
        Date.parse(k["PostingDate"]) > last_seen &&
        k["SupportedDevices"].any? { |v| v.start_with?("iPhone") }
      end
    end

    def nothing_is_enabled?
      !config['slack']['enabled'] && !config['sms']['enabled'] && !config['smtp']['enabled']
    end

    def pmv
      response = HTTParty.get("https://gdmf.apple.com/v2/pmv", { ssl_ca_file: "#{__dir__}/apple.pem", headers: {"User-Agent" => "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:98.0) Gecko/20100101 Firefox/98.0"} })
      JSON.parse(response.body)
    end

    def send_notifications(notification_text)
      if nothing_is_enabled?
        say("No notification methods are enabled.", :red)
        puts "Please edit the config.yml file and enable at least one type of notification."
        exit(false)
      end

      UpdateNotifier::Slack.send(notification_text, config['slack'])
      UpdateNotifier::SMS.send(notification_text, config['sms'])
      UpdateNotifier::SMTP.send(notification_text, config['smtp'])
    end

    def update_last_seen(date)
        File.write(last_seen_file, date.strftime("%Y-%m-%d"))
    end

    def self.exit_on_failure?
      true
    end

  end
end

UpdateNotifier::CLI.start(ARGV)
