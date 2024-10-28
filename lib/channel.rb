module UpdateNotifier
  class Channel
    attr_reader :channel, :platform, :pmv

    def initialize(channel, platform, pmv)
      @channel = channel
      @platform = platform

      # If Apple hasn't released any recent Rapid Security Responses,
      # the relevant JSON will be empty.
      @pmv = pmv[channel][platform].nil? ? Array.new : pmv[channel][platform]
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
      if File.exist?(last_seen_file)
        File.read(last_seen_file)
      else
        puts "First run! Creating `#{last_seen_file}` to track #{platform} updates on Apple's '#{channel}' channel."

        latest_version_number = version_number(highest_version(pmv))

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
      if rapid_channel? && !last_seen.nil?
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
      rapid_index_url     = "https://support.apple.com/en-us/HT201224"
      security_index_url  = "https://support.apple.com/en-us/HT201222"
      security_index_html = HTTParty.get(security_index_url).body

      doc = Nokogiri::HTML(security_index_html)

      # Apple omits the trailing '.0' in link text for new major versions
      if version.end_with?(".0")
        version.delete!(".0")
      end

      if rapid_channel?
        rsr_search_results = doc.search("a[text()^='Rapid Security Response']").select do |link|
          link.text.include?(platform) && link.text.end_with?(version)
        end

        version_link = rsr_search_results.first
      else
        if platform == "iOS"
          version_link = doc.at("a[text()^='iOS #{version}']")
        elsif platform == "macOS"
          version_link = doc.search("a[text()^='macOS']").select { |link| link.text.end_with?(version) }.first
        end
      end

      if version_link.nil?
        rapid_channel? ? rapid_index_url : security_index_url
      else
        version_link[:href]
      end
    end

    def send_latest_update_notification
      latest_update = highest_version(new_updates)

      if latest_update.nil?
        puts "No new #{platform} updates found on Apple's '#{channel}' channel."
      else
        puts "New update found: #{platform} #{latest_update["ProductVersion"]} #{latest_update["ProductVersionExtra"]} (#{latest_update["PostingDate"]}) -- Sending notifications."

        latest_version_number = version_number(latest_update)

        update_last_seen(latest_version_number)

        cli = UpdateNotifier::CLI.new
        notification_text = cli.config["notification_text"].dup
        notification_text.gsub!("$PLATFORM", platform)
        notification_text.gsub!("$LINK",     security_link(latest_version_number))
        notification_text.gsub!("$VERSION",  latest_version_number)
        cli.send_notifications(notification_text)
      end
    end

    def update_last_seen(version)
      File.write(last_seen_file, version)
    end

    def version_number(update)
      unless update.nil?
        if rapid_channel?
          "#{update["ProductVersion"]} #{update["ProductVersionExtra"]}"
        else
          update["ProductVersion"]
        end
      end
    end

  end
end
