# Changelog for hubot-service-now

# v1.4.0
- Fixed [#13](https://github.com/disney/hubot-service-now/issues/13) - Fix regex in formatter
- Fixed [#14](https://github.com/disney/hubot-service-now/issues/14) - Add support for STRY (Scrum Story) and STSK (Scrum Task) records
- Add debug logging for Service Now response
- Fix extra space in 'ignoring explicit Service Now request' debug log message

# v1.3.0
- Fixed [#11](https://github.com/disney/hubot-service-now/issues/11) - Add Support for SCTASK records
  - This required changing the regex match since the record type is a character longer than the others
- CHG records: switch from "Opened At" to "Start" and "End"
- Add explicit curly braces (address coffeelint rule)
- Add spaces between closing square brackets (`]`) and closing curly braces (`}`) to (address coffeelint rule)

# v1.2.0
- Fixed [#10](https://github.com/disney/hubot-service-now/issues/10) - Use open-ended regex matching for the integer portion of ticket numbers
- Add support for CTASK records

# v1.1.1
- Fixed [#8](https://github.com/disney/hubot-service-now/issues/8) - Handle Slack's new location to save is_bot value for message user
- Add some additional debug logging

# v1.1.0
- Add support for returning hyperlinked ticket IDs
  - This Fixes https://github.com/disney/hubot-service-now/issues/3
  - For users directly using the `sn_single_result_fmt` event handler, backwards compability has been preserved; only events with `result` values that contain a `sys_id` field will have links created for them
  - In order to have links be generated for event notifications to `sn_single_record_fmt`, please make sure that the `result` object contains a key/value for `sys_id`
- Update tests accordingly
- Clean up strings that wrap lines
- Tighten dev dependencies down to known-working versions

# v1.0.1
- Add support for hubot 3.x and hubot-redis-brain 1.0.0
- Add list of supported record types to README
- add CHANGELOG

# v1.0.0
- Initial Release
