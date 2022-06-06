#!/usr/bin/env ruby

require 'bundler/setup'
require 'date'
require 'httparty'
require 'json'
require 'nokogiri'
require 'thor'
require 'yaml'
require_relative 'lib/discord.rb'
require_relative 'lib/signal.rb'
require_relative 'lib/simpletexting-sms.rb'
require_relative 'lib/slack.rb'
require_relative 'lib/smtp.rb'
require_relative 'lib/telegram.rb'
require_relative 'lib/twilio-sms.rb'
require_relative 'lib/twitter.rb'

module UpdateNotifier
  class CLI < Thor

    desc "notify", "Send a notification if a new iOS update has been released since the last update was seen."
    long_desc <<-LONGDESC
      When the command is run for the first time, a new `LAST_SEEN` file is created
      to store the version number of the latest iOS release. Notifications are only
      sent if a new release is discovered with a version number that is larger than
      the latest value in the `LAST_SEEN` file.

      As a result (and by design) the initial run will never trigger notifications.

      During subsequent runs, notifications are sent and the `LAST_SEEN` value is
      updated whenever a new version is detected.
    LONGDESC
    def notify
      latest_update = highest_version(new_updates)

      if latest_update.nil?
        puts "No new updates found."
      else
        puts "New update found: #{latest_update['ProductVersion']} (#{latest_update['PostingDate']}) -- Sending notifications."

        config['notification_text'].gsub!('$VERSION', latest_update['ProductVersion'])
        config['notification_text'].gsub!('$LINK',    security_link(latest_update['ProductVersion']))

        send_notifications(config['notification_text'])
        update_last_seen(latest_update['ProductVersion'])
      end

      File.write("#{__dir__}/LAST_RUN", DateTime.now)
    end

    desc "show", "Show information about the latest iOS release."
    def show
      show_release = highest_version(pmv)

      say("Latest iOS release information:", :green)
      puts "  Version:  #{show_release['ProductVersion']}"
      puts "  Released: #{show_release['PostingDate']}"
      puts "  Expires:  #{show_release['ExpirationDate']}"
      puts "  Link:     #{security_link(show_release['ProductVersion'])}"
      puts "  Supported devices (#{show_release['SupportedDevices'].size}):"
      puts "    #{show_release['SupportedDevices']}"
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
      puts "  - Discord"             if service_is_enabled?('discord')
      puts "  - Signal"              if service_is_enabled?('signal')
      puts "  - Slack"               if service_is_enabled?('slack')
      puts "  - SMS (SimpleTexting)" if service_is_enabled?('simpletexting_sms')
      puts "  - SMS (Twilio)"        if service_is_enabled?('twilio_sms')
      puts "  - SMTP"                if service_is_enabled?('smtp')
      puts "  - Telegram"            if service_is_enabled?('telegram')
      puts "  - Twitter"             if service_is_enabled?('twitter')

      say("\nTest message:", :green)
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

    def highest_version(versions)
      versions.max_by { |v| Gem::Version.new(v['ProductVersion']) }
    end

    def last_seen
      if File.exists?(last_seen_file)
        return Gem::Version.new(File.read(last_seen_file))
      else
        say("First run! Creating a new `LAST_SEEN` file.", :green)
        latest_version_number = highest_version(pmv)['ProductVersion']

        update_last_seen(latest_version_number)
        return Gem::Version.new(latest_version_number)
      end
    end

    def last_seen_file
      "#{__dir__}/LAST_SEEN"
    end

    def new_updates
      pmv.select do |k, v|
        Gem::Version.new(k['ProductVersion']) > last_seen &&
        k['SupportedDevices'].any? { |v| v.start_with?("iPhone") }
      end
    end

    def pmv
      # https://developer.apple.com/business/documentation/MDM-Protocol-Reference.pdf#86
      @response ||= HTTParty.get("https://gdmf.apple.com/v2/pmv", { ssl_ca_file: "#{__dir__}/ca/apple.pem", headers: {"User-Agent" => "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:98.0) Gecko/20100101 Firefox/98.0"} })
      JSON.parse(@response.body)['PublicAssetSets']['iOS']
    end

    def security_link(version)
      security_index_url  = "https://support.apple.com/en-us/HT201222"
      security_index_html = HTTParty.get(security_index_url).body

      doc = Nokogiri::HTML(security_index_html)

      version_link = doc.at("a[text()^='iOS #{version}']")

      if version_link.nil?
        return security_index_url
      else
        return version_link[:href]
      end
    end

    def send_notifications(notification_text)
      UpdateNotifier::Discord.notify(notification_text, config['discord']) if service_is_enabled?('discord')
      UpdateNotifier::Signal.notify(notification_text, config['signal']) if service_is_enabled?('signal')
      UpdateNotifier::SimpleTextingSMS.notify(notification_text, config['simpletexting_sms']) if service_is_enabled?('simpletexting_sms')
      UpdateNotifier::Slack.notify(notification_text, config['slack']) if service_is_enabled?('slack')
      UpdateNotifier::SMTP.notify(notification_text, config['smtp']) if service_is_enabled?('smtp')
      UpdateNotifier::Telegram.notify(notification_text, config['telegram']) if service_is_enabled?('telegram')
      UpdateNotifier::TwilioSMS.notify(notification_text, config['twilio_sms']) if service_is_enabled?('twilio_sms')
      UpdateNotifier::Twitter.notify(notification_text, config['twitter']) if service_is_enabled?('twitter')
    end

    def service_is_enabled?(service)
      if config[service].nil?
        return false
      elsif config[service]['enabled'].nil?
        return false
      else
        return config[service]['enabled']
      end
    end

    def update_last_seen(version_number)
      File.write(last_seen_file, version_number)
    end

    def self.exit_on_failure?
      true
    end

  end
end

UpdateNotifier::CLI.start(ARGV)
