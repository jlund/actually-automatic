#!/usr/bin/env ruby

require 'bundler/setup'
require 'date'
require 'httparty'
require 'json'
require 'nokogiri'
require 'thor'
require 'yaml'
require_relative 'lib/channel.rb'
require_relative 'lib/discord.rb'
require_relative 'lib/signal.rb'
require_relative 'lib/simpletexting-sms.rb'
require_relative 'lib/slack.rb'
require_relative 'lib/smtp.rb'
require_relative 'lib/telegram.rb'
require_relative 'lib/twilio-sms.rb'

module UpdateNotifier
  class CLI < Thor

    desc "notify (--ios) (--macos)", "Send a notification if new updates for the specified platforms have been released since the last updates were seen."
    long_desc <<-LONGDESC
      When the command is run for the first time, new `LAST_SEEN_*` files are created
      to store the version numbers of the latest macOS and iOS releases. Notifications
      are only sent if new releases are discovered with version numbers that are larger
      than the latest values in the `LAST_SEEN_*` files.

      As a result (and by design) the initial run will never trigger notifications.

      During subsequent runs, notifications are sent and the `LAST_SEEN_*` values are
      updated whenever new versions are detected.
    LONGDESC
    option :ios,   type: :boolean
    option :macos, type: :boolean
    def notify
      unless options[:ios] || options[:macos]
        say("No platforms selected!", :red)
        puts "Please specify `--ios` and/or `--macos`."
        exit(false)
      end

      if options[:ios]
        ios_production = UpdateNotifier::Channel.new("PublicAssetSets", "iOS", pmv)
        ios_rapid      = UpdateNotifier::Channel.new("PublicRapidSecurityResponses", "iOS", pmv)

        ios_production.send_latest_update_notification
        ios_rapid.send_latest_update_notification
      end

      if options[:macos]
        macos_production = UpdateNotifier::Channel.new("PublicAssetSets", "macOS", pmv)
        macos_rapid      = UpdateNotifier::Channel.new("PublicRapidSecurityResponses", "macOS", pmv)

        macos_production.send_latest_update_notification
        macos_rapid.send_latest_update_notification
      end

      File.write("#{__dir__}/LAST_RUN", DateTime.now)
    end

    desc "show", "Show information about the latest iOS and macOS releases."
    def show
      say("Latest release information:", :green)
      show_release("PublicAssetSets", "iOS")
      show_release("PublicRapidSecurityResponses", "iOS")
      show_release("PublicAssetSets", "macOS")
      show_release("PublicRapidSecurityResponses", "macOS")
    end

    desc "test", "Send a test message to verify that notifications are configured correctly."
    option :message, required: true
    def test
      test_message = options[:message].chomp

      say("Config info:", :green)
      puts "  You can edit the `config.yml` file to configure and enable"
      puts "  different notification services."
      puts "    e.g. `enabled: no` -> `enabled: yes` or `enabled: true`\n\n"

      say("Services enabled:", :green)
      puts "  - Discord"             if service_is_enabled?("discord")
      puts "  - Signal"              if service_is_enabled?("signal")
      puts "  - Slack"               if service_is_enabled?("slack")
      puts "  - SMS (SimpleTexting)" if service_is_enabled?("simpletexting_sms")
      puts "  - SMS (Twilio)"        if service_is_enabled?("twilio_sms")
      puts "  - SMTP"                if service_is_enabled?("smtp")
      puts "  - Telegram"            if service_is_enabled?("telegram")

      say("\nTest message:", :green)
      puts "  #{test_message}\n\n"

      continue = ask("Would you like to continue?", limited_to: ["yes", "no"], default: "no")

      if continue == "yes"
        send_notifications(test_message)
      end
    end

    no_commands do
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

      def send_notifications(notification_text)
        UpdateNotifier::Discord.notify(notification_text, config["discord"]) if service_is_enabled?("discord")
        UpdateNotifier::Signal.notify(notification_text, config["signal"]) if service_is_enabled?("signal")
        UpdateNotifier::SimpleTextingSMS.notify(notification_text, config["simpletexting_sms"]) if service_is_enabled?("simpletexting_sms")
        UpdateNotifier::Slack.notify(notification_text, config["slack"]) if service_is_enabled?("slack")
        UpdateNotifier::SMTP.notify(notification_text, config["smtp"]) if service_is_enabled?("smtp")
        UpdateNotifier::Telegram.notify(notification_text, config["telegram"]) if service_is_enabled?("telegram")
        UpdateNotifier::TwilioSMS.notify(notification_text, config["twilio_sms"]) if service_is_enabled?("twilio_sms")
      end
    end

    private

    def pmv
      # https://developer.apple.com/business/documentation/MDM-Protocol-Reference.pdf#86
      @response ||= HTTParty.get("https://gdmf.apple.com/v2/pmv", { ssl_ca_file: "#{__dir__}/ca/apple.pem", headers: {"User-Agent" => "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0"} })
      @json ||= JSON.parse(@response.body)
    end

    def self.exit_on_failure?
      true
    end

    def service_is_enabled?(service)
      if config[service].nil?
        false
      elsif config[service]["enabled"].nil?
        false
      else
        config[service]["enabled"]
      end
    end

    def show_release(channel, platform)
      release_channel = UpdateNotifier::Channel.new(channel, platform, pmv)
      latest          = release_channel.highest_version(release_channel.pmv)

      latest_version_number = release_channel.version_number(latest)

      say("Platform: #{platform} | Channel: #{channel}", :bold)
      puts "  Version:  #{latest_version_number}"
      puts "  Released: #{latest["PostingDate"]}"
      puts "  Expires:  #{latest["ExpirationDate"]}"
      puts "  Link:     #{release_channel.security_link(latest_version_number)}"
      puts "  Supported devices (#{latest["SupportedDevices"].size}):"
      puts "    #{latest["SupportedDevices"]}\n\n"
    end

  end
end

UpdateNotifier::CLI.start(ARGV)
