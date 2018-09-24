# Changelog for hubot-service-now

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
