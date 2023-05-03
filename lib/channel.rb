module UpdateNotifier
  class Channel
    attr_reader :channel, :platform, :pmv

    def initialize(channel, platform, pmv)
      @channel = channel
      @platform = platform
      @pmv = pmv[channel][platform]
    end

    def highest_version(versions)
      max_version = versions.max_by { |v| Gem::Version.new(v["ProductVersion"]) }

      if rapid_channel?
        # Find all of the possible "extra" matches for the maximum version
        # number within the rapid channel
        extra_versions = versions.select do |k, v|
          k["ProductVersion"].eql?(max_version["ProductVersion"])
        end

        # Only return the version with the highest "extra" parenthetical value
        # (e.g. "16.4.1 (b)" should be returned ahead of "16.4.1 (a)")
        extra_versions.max_by { |v| v["ProductVersionExtra"] }
      else
        max_version
      end
    end

    def last_seen
      if File.exists?(last_seen_file)
        File.read(last_seen_file)
      else
        puts "First run! Creating `#{last_seen_file}` to track #{platform} updates on Apple's '#{channel}' channel."

        if rapid_channel?
          latest_version_number = "#{highest_version(pmv)["ProductVersion"]} #{highest_version(pmv)["ProductVersionExtra"]}"
        else
          latest_version_number = highest_version(pmv)["ProductVersion"]
        end

        update_last_seen(latest_version_number)
        latest_version_number
      end
    end

    def last_seen_file
      filename = "#{__dir__}/../LAST_SEEN_#{platform.upcase}"

      if rapid_channel?
        filename.concat("_RAPID")
      else
        filename
      end
    end

    def new_updates
      if rapid_channel?
        version_split = last_seen.split(" ")

        last_seen_version = version_split[0]
        last_seen_extra   = version_split[1]

        platform_updates = pmv.select do |k, v|
          Gem::Version.new(k["ProductVersion"]) > Gem::Version.new(last_seen_version) ||
          (Gem::Version.new(k["ProductVersion"]) == Gem::Version.new(last_seen_version) && k["ProductVersionExtra"] > last_seen_extra)
        end
      else
        platform_updates = pmv.select do |k, v|
          Gem::Version.new(k["ProductVersion"]) > Gem::Version.new(last_seen)
        end
      end

      if platform == "iOS"
        platform_updates.select do |k, v|
          # Filter out tvOS and watchOS releases
          k["SupportedDevices"].any? { |v| v.start_with?("iPhone") }
        end
      elsif platform == "macOS"
        platform_updates
      end
    end

    def rapid_channel?
      channel == "PublicRapidSecurityResponses" ? true : false
    end

    def security_link(version)
      # TODO It's unclear how (or if) Apple will post update information
      # or release notes for Rapid Security Responses. They didn't for
      # the first release, but this logic should be revisited after
      # there have been more.
      if rapid_channel?
        "https://support.apple.com/en-us/HT201224"
      else
        security_index_url = "https://support.apple.com/en-us/HT201222"
        @security_index_html ||= HTTParty.get(security_index_url).body

        doc = Nokogiri::HTML(@security_index_html)

        # Apple omits the trailing '.0' in link text for new major versions
        if version.end_with?(".0")
          version.delete!(".0")
        end

        if platform == "iOS"
          version_link = doc.at("a[text()^='iOS #{version}']")
        elsif platform == "macOS"
          version_link = doc.search("a[text()^='macOS']").select { |link| link.text.end_with?(version) }.first
        end

        if version_link.nil?
          security_index_url
        else
          version_link[:href]
        end
      end
    end

    def send_latest_update_notification
      latest_update = highest_version(new_updates)

      if latest_update.nil?
        puts "No new #{platform} updates found on Apple's '#{channel}' channel."
      else
        puts "New update found: #{platform} #{latest_update["ProductVersion"]} #{latest_update["ProductVersionExtra"]} (#{latest_update["PostingDate"]}) -- Sending notifications."

        if rapid_channel?
          latest_version = "#{latest_update["ProductVersion"]} #{latest_update["ProductVersionExtra"]}"
        else
          latest_version = latest_update["ProductVersion"]
        end

        update_last_seen(latest_version)

        cli = UpdateNotifier::CLI.new
        notification_text = cli.config["notification_text"].dup
        notification_text.gsub!("$PLATFORM", platform)
        notification_text.gsub!("$LINK",     security_link(latest_update["ProductVersion"]))
        notification_text.gsub!("$VERSION",  latest_version)
        cli.send_notifications(notification_text)
      end
    end

    def update_last_seen(version)
      File.write(last_seen_file, version)
    end

  end
end
