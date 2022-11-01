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
      unless options[:macos] || options[:ios]
        say("No platforms selected!", :red)
        puts "Please specify `--ios` and/or `--macos`."
        exit(false)
      end

      latest_update_notification('iOS')   if options[:ios]
      latest_update_notification('macOS') if options[:macos]

      File.write("#{__dir__}/LAST_RUN", DateTime.now)
    end

    desc "show", "Show information about the latest iOS and macOS releases."
    def show
      show_release('iOS')
      show_release('macOS')
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

    def last_seen(platform)
      if File.exists?(last_seen_file(platform))
        return Gem::Version.new(File.read(last_seen_file(platform)))
      else
        say("First run! Creating a new `LAST_SEEN_#{platform.upcase}` file for #{platform}.", :green)
        latest_version_number = highest_version(pmv(platform))['ProductVersion']

        update_last_seen(platform, latest_version_number)
        return Gem::Version.new(latest_version_number)
      end
    end

    def last_seen_file(platform)
      "#{__dir__}/LAST_SEEN_#{platform.upcase}"
    end

    def latest_update_notification(platform)
      latest_update = highest_version(new_updates(platform))

      if latest_update.nil?
        puts "No new #{platform} updates found."
      else
        puts "New #{platform} update found: #{latest_update['ProductVersion']} (#{latest_update['PostingDate']}) -- Sending notifications."

        notification_text = config['notification_text'].dup

        notification_text.gsub!('$PLATFORM', platform)
        notification_text.gsub!('$VERSION',  latest_update['ProductVersion'])
        notification_text.gsub!('$LINK',     security_link(platform, latest_update['ProductVersion']))

        send_notifications(notification_text)
        update_last_seen(platform, latest_update['ProductVersion'])
      end
    end

    def new_updates(platform)
      platform_updates = pmv(platform).select do |k, v|
        Gem::Version.new(k['ProductVersion']) > last_seen(platform)
      end

      if platform == 'iOS'
        platform_updates.select do |k, v|
          # Filter out tvOS and watchOS releases
          k['SupportedDevices'].any? { |v| v.start_with?("iPhone") }
        end
      elsif platform == 'macOS'
        platform_updates
      end
    end

    def pmv(platform)
      # https://developer.apple.com/business/documentation/MDM-Protocol-Reference.pdf#86
      @response ||= HTTParty.get("https://gdmf.apple.com/v2/pmv", { ssl_ca_file: "#{__dir__}/ca/apple.pem", headers: {"User-Agent" => "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:106.0) Gecko/20100101 Firefox/106.0"} })
      JSON.parse(@response.body)['PublicAssetSets'][platform]
    end

    def security_link(platform, version)
      security_index_url = "https://support.apple.com/en-us/HT201222"
      @security_index_html ||= HTTParty.get(security_index_url).body

      doc = Nokogiri::HTML(@security_index_html)

      # Apple omits the trailing '.0' in link text for new major versions
      if version.end_with?('.0')
        version.delete!('.0')
      end

      if platform == 'iOS'
        version_link = doc.at("a[text()^='iOS #{version}']")
      elsif platform == 'macOS'
        version_link = doc.search("a[text()^='macOS']").select { |link| link.text.end_with?(version) }.first
      end

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

    def show_release(platform)
      latest = highest_version(pmv(platform))

      say("Latest #{platform} release information:", :green)
      puts "  Version:  #{latest['ProductVersion']}"
      puts "  Released: #{latest['PostingDate']}"
      puts "  Expires:  #{latest['ExpirationDate']}"
      puts "  Link:     #{security_link(platform, latest['ProductVersion'])}"
      puts "  Supported devices (#{latest['SupportedDevices'].size}):"
      puts "    #{latest['SupportedDevices']}"
    end

    def update_last_seen(platform, version_number)
      File.write(last_seen_file(platform), version_number)
    end

    def self.exit_on_failure?
      true
    end

  end
end

UpdateNotifier::CLI.start(ARGV)
