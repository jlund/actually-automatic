# Actually Automatic
## Self-Hosting Instructions

### Initial Setup (Ubuntu 24.04)
1. Install Ruby and compilation dependencies:
   * `sudo apt install ruby ruby-bundler ruby-dev build-essential`
2. Create a new user account that will run the update checks and whose home directory will store the program:
   * `sudo adduser softwareupdates`
3. Switch to the new user account:
   * `sudo su -l softwareupdates`
4. Clone the repository:
   * `git clone https://github.com/jlund/actually-automatic.git`
5. Install the bundle:
   * `bundle config set path 'vendor/bundle'`
   * `cd actually-automatic && bundle install`
6. Create a copy of the sample configuration file:
   * `cp config.yml.sample config.yml`
7. **(Optional)** To enable support for sending update notifications via [Signal](https://signal.org/), you will need to [install](https://github.com/AsamK/signal-cli#installation) and [configure](https://github.com/AsamK/signal-cli/wiki/Quickstart#set-up-an-account) the *unofficial* [signal-cli](https://github.com/AsamK/signal-cli) client.
     * The Signal account registration and verification commands should be performed as the same user that will run the scheduled update checks (e.g. `softwareupdates`) so that the necessary cryptographic keys and Signal-specific configuration files are created in the correct home directory.
     * Signal notifications are considered experimental.
     * There isn't currently an officially supported method for sending programmatic Signal messages (e.g. from bots like this).
8. Update the config:
   * `text-editor-of-your-choice config.yml`

Now that the program is configured and installed, it's important to make sure that everything is working properly before enabling the automatic update checks.

### Testing

There are two available subcommands that are useful for testing purposes.

* Show information about the latest iOS and macOS releases:
  * `./update-notifier.rb show`
* Send a test message:
  * `./update-notifier.rb test --message "This is a test of the software update notification broadcast system. This is only a test."`
    * Test messages will be sent through any enabled notification methods. You will be asked to confirm delivery before any test messages are sent.

If these commands both work, then you're almost done. The final step is to configure your server to periodically check for new iOS updates.

### Enabling Scheduled Update Checks

1. Run the `notify` subcommand to verify that it is working too.
   * `./update-notifier.rb notify --ios --macos`
     * If you only want to receive notifications for one of the platforms, you can remove the `--ios` or `--macos` flag accordingly.
     * If it's the first time the program has been run on this server, new `LAST_SEEN` files will be created to store the latest version numbers.
     * The initial run will never trigger notifications. Notifications are only sent if a new release is discovered with a version number that is larger than the latest value in the relevant `LAST_SEEN_*` file.
2. Edit the crontab to periodically run the `notify` subcommand:
   * `crontab -e`
3. Add this line to the bottom of the file to check for iOS and macOS updates every 45 minutes:
   * `*/45 * * * * cd /home/softwareupdates/actually-automatic && ruby update-notifier.rb notify --ios --macos`
   * Be sure to update the home directory if you chose a different username.
4. **Optional:** If you have configured Signal notifications via `signal-cli`, you may also want to add the following lines to the crontab to periodically process incoming messages (e.g. when new people join the group chat where you're sending notifications) and to clean up attachment downloads:
   * `15 */4 * * * /usr/local/bin/signal-cli -u +18015551234 receive`
     * Be sure to replace the 555 example number with the number `signal-cli` is using.
   * `@daily rm -rf /home/softwareupdates/.local/share/signal-cli/attachments`

All set! You can verify that the cron is working by watching the timestamp in the `LAST_RUN` file in the repo directory.
