# Quasi Automatic - iOS Update Notifier

The "Automatic Updates" feature in iOS can be slow and unpredictable. Start installing the latest security fixes and new features without the wait! Get notified via Slack, email, and/or SMS whenever Apple releases a new iOS update.

The choice is yours:
* Set this little program up on your own server.
  * Protocols supported: Slack, SMS (via [SimpleTexting](https://simpletexting.com/) or [Twilio](https://www.twilio.com/sms)), and SMTP (for email alerts).
* Or simply text "subscribe" to ***+1-833-942-4941*** to sign up to receive informational text messages about new iOS releases.
  * Notifications are sent using the same open source program in this repo.
  * Your number will never be bought or sold or used for any other purposes.
  * This is a toll-free number, but carrier message and data rates may apply.
    * In other words, your cellular provider may charge you to send and receive text messages, but this number itself doesn't cost anything extra.
  * Text "stop" to instantly unsubscribe.

## Questions and Answers

### Why is this important?

**iOS doesn't tell you when a new update is available.**

It can take several days (or longer!) before your phone even attempts to download a new update. At the same time, almost every new iOS release includes important security updates and bug fixes for a variety of vulnerabilities. It's increasingly common for this boilerplate statement to appear within iOS update documents:

> Apple is aware of a report that this issue may have been actively exploited.

Quickly installing updates is a good habit to get into, and this project's goal is to help make that a littler easier.

### Wait, aren't iOS updates automatic?

Sort of. Sometimes.

If Automatic Updates are enabled (`Settings > General > Software Update > Automatic Updates`), an iPhone *might* decide to download and install a new iOS update when all of the following conditions are true:

1. It's plugged in or resting on a wireless charger.
2. It's connected to WiFi.
3. It thinks that it's "overnight."
   * Users can also chose an installation time in the notification that only appears **after** an update has already been downloaded, but this download won't happen automatically without a WiFi connection.

There are a lot of ways that three seemingly simple rules can sometimes go wrong ([just ask Isaac Asimov](https://en.wikipedia.org/wiki/Three_Laws_of_Robotics)). These rules are no exception.

Here are a few examples where automatic updates sometimes don't work very well under real-world conditions:

* **No WiFi.**
  * No automatic updates.
* **Annoying captive-portal WiFi.**
  * Unless you really commit to repeatedly filling out those tiny forms that ask for your last name and hotel room number every couple of hours, you might not be connected to WiFi during the pivotal and opaque moment when iOS decides to check for and download an update.
* **You have the audacity to charge your phone during the day or in your own car.**
  * There might not be a need to plug in your phone again at home if it's already fully charged.
  * You probably don't have WiFi in your car.
* **You recently flew through the air on a work trip or dream vacation.**
  * The concept of "overnight" isn't always compatible with time zones (or adventure).

### How quickly are automatic updates applied under perfect conditions?

Apple regularly publishes detailed revisions to their [Apple Platform Security documentation](https://support.apple.com/guide/security/welcome/web), but even though the subject of "Automatic Updates" seems highly relevant to this topic, that phrase is only mentioned twice overall — and only once in the context of iOS in Apple's [latest PDF guide](https://manuals.info.apple.com/MANUALS/1000/MA1902/en_US/apple-platform-security-guide.pdf) that spans more than 210 pages (as of April 2022).

Very few details are provided. Dedicated readers can learn a few fascinating facts about the "Escrow keybag" where automatic updates are briefly mentioned, but there's nothing about when and how update checks are performed, or what protections (if any) are in place to ensure that users will eventually find out about available updates with critical security fixes.

Even with the ideal combination of flawless WiFi, an uninterrupted connection to power, and a stable "overnight" situation, automatic updates can still take quite a while. A [popular thread on Reddit](https://www.reddit.com/r/ios/comments/trj7c1/craig_federighis_response_to_question_about_ios/) was started after Apple's Senior Vice President of Software Engineering purportedly responded to an email inquiry that was sent on behalf of Apple users who were confused about how Automatic Updates were supposed to work.

The reply from [Craig Federighi](https://www.apple.com/leadership/craig-federighi/) (which exists in the form of a screenshot, not in any official documentation) states that iOS updates are rolled out incrementally and that automatic updates begin "1-4 weeks later (after we've received feedback on the update)."

For users in high-risk environments or professions, "1-4 weeks later" could feel approximately 1-4 weeks too late.

### Shouldn't people be given the option to get notified about new updates right away?

A staged roll-out strategy (that can take up to 4 weeks!) makes a bit of sense when introducing new features. Let the enthusiasts who habitually check for updates in the Settings app kick the tires for a bit first, and then start a full-scale roll-out after responding to their feedback and making any necessary adjustments.

The problem, of course, is that Apple oftentimes deploys fixes for critical security vulnerabilities right alongside new features in the same release. A month-long staged roll-out process arguably doesn't make much sense for something like a use-after-free vulnerability that places millions of users and their data at risk of compromise.

Apple could easily add an additional toggle to the existing Automatic Updates settings page (e.g. "Notify When Available") and this entire project would no longer be necessary.

Hopefully they will do that someday.

### Does quickly installing updates really matter?

It's difficult to fix something without also revealing what's broken. Within moments of any new iOS release, people all over the world start closely examining the changes. Some of those people are not good people, and some of them learn about new vulnerabilities that they can start exploiting right away before the update has been widely deployed.

Similarly, any attackers who already knew about the vulnerability previously had a reason to be judicious and careful in how they used it. They wanted the vulnerability to remain secret so that Apple wouldn't fix it. However, now they may instead be motivated to race against the update and try to compromise as many devices as possible before the window for exploiting this previously hidden vulnerability has completely closed. 

When it comes to installing security-related bug fixes and updates, faster is always better.

## Legal

All trademarks are property of their respective trademark holders. Not affiliated with Apple.
