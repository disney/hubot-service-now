# Description:
#   Service Now Record lookup
#
# Commands:
#   hubot <sn|snapi|service now> <record number> - Look up record number in Service Now
#   hubot <sn|snapi|service now> listen - Toggle Implicit/Explicit listening for Service Now records
#
# Configuration:
#   HUBOT_SERVICE_NOW_INSTANCE: Service Now instance (e.g. 'devtest' of devtest.service-now.com)
#   HUBOT_SERVICE_NOW_DOMAIN: Override FQDN for service now instance
#     useful if you need to use an internal proxy
#   HUBOT_SERVICE_NOW_USER: Service Now API Username
#   HUBOT_SERVICE_NOW_PASSWORD: Service Now API Password


module.exports = (robot) ->
  sn_domain = process.env.HUBOT_SERVICE_NOW_DOMAIN
  sn_instance = process.env.HUBOT_SERVICE_NOW_INSTANCE
  if sn_domain? and sn_instance?
    robot.logger.error "HUBOT_SERVICE_NOW_DOMAIN and " +
    "HUBOT_SERVICE_NOW_INSTANCE can't be set at the same time. Use one or the other"
  else if sn_domain?
    sn_fqdn = "https://#{sn_domain}"
  else if sn_instance?
    sn_fqdn = "https://#{sn_instance}.service-now.com"
  robot.logger.debug("sn_fqdn: #{sn_fqdn}")
  ###
  The bit that does the work to ask Service Now for stuff is registered as an
  event so that you can consume this in other scripts if you'd like.
  The expected format of the 'request' object is as follows:
  request =
    table,
    rec_number,
    fields,
    user

    table and rec_number should be strings
    fields should be an object of keys/values, where the key is the record field
      and the value is the human-readable description
    The user object should be a room or user that the script should return
      the results to
  ###
  robot.on "sn_record_get", (request) ->
    query_fields = Object.keys(request.fields)

    # inject sys_id to query_fields for use later
    query_fields.push 'sys_id'

    api_url = "#{sn_fqdn}/api/now/v2/table/#{request.table}"
    req_args = "sysparm_query=number=#{request.rec_number}&" +
      "sysparm_display_value=true&sysparm_limit=1&sysparm_fields=#{query_fields}"
    sn_url = "#{api_url}?#{req_args}"

    robot.logger.debug "SN URL: #{sn_url}"
    sn_user = process.env.HUBOT_SERVICE_NOW_USER
    sn_pass = process.env.HUBOT_SERVICE_NOW_PASSWORD

    unless sn_user? and sn_pass?
      robot.logger.error "HUBOT_SERVICE_NOW_USER and HUBOT_SERVICE_NOW_PASSWORD " +
        "Must be defined!"
      robot.send request.user, "Integration user name and password are not " +
        "defined. I can't look up Service Now Requests without them"

    robot.http(sn_url)
      .header('Accept', 'application/json')
      .auth(process.env.HUBOT_SERVICE_NOW_USER,
        process.env.HUBOT_SERVICE_NOW_PASSWORD)
      .get() (err, res, body) ->
        if (err?)
          robot.send request.user, err
          robot.send request.user, "Error was encountered while looking for " +
            "`#{request.rec_number}`"
          robot.logger.error "Received error #{err} when looking for " +
            "`#{request.rec_number}`"
          return

        data = JSON.parse body
        result = data['result']

        unless result?
          robot.send request.user, "Error was encountered while looking for " +
            "`#{request.rec_number}`"
          robot.logger.error "Received error '#{data.error.message}' while " +
            "looking for '#{request.rec_number}'"
          return

        if (result.length < 1)
          robot.send request.user, "Service Now returned 0 records for " +
            "'#{request.rec_number}'"
        else
          rec_count = res.headers['X-Total-Count']
          if (rec_count > 1)
            robot.send request.user, "Service Now returned #{rec_count} " +
              "records. Showing the first"
          sn_single_result_fmt(request.user, request.fields,
            request.rec_number, result[0])

  sn_single_result_fmt = (user, fields, rec_number, result) ->
    # if we have a sys_id field in the results, use it to generate a URL to the record
    if 'sys_id' in Object.keys(result)
      # get record type from rec_number and look up service now table
      rec_type = rec_number.match(/([A-z]{3,5})([0-9]{7,})/)[1]
      sn_table = table_lookup[rec_type]['table']

      # construct URL to record
      sn_url = "#{sn_fqdn}/nav_to.do?uri=/#{sn_table}.do?sys_id=#{result['sys_id']}"
      # create hyperlink
      output = "Found *<#{sn_url}|#{rec_number}>:*"
    else
      output = "Found *#{rec_number}:*"

    for k, v of fields
      robot.logger.debug "Getting #{k} from result"
      output += "\n*#{v}:* #{result[k]}"

    robot.send user, output
    return

  robot.respond /(?:sn(?:ow)?|service now) ([A-z]{3,6})([0-9]{7,})/i, (res) ->
    rec_type = res.match[1]
    rec_num = res.match[2]

    if table_lookup[rec_type]?
      robot.logger.debug "Record: #{rec_type}#{rec_num}"
      robot.logger.debug "user: #{res.message.user.name}"
      robot.logger.debug "table: #{table_lookup[rec_type]['table']}"
      robot.emit "sn_record_get", {
        user: res.message.user,
        table: table_lookup[rec_type]['table'],
        fields: table_lookup[rec_type]['fields']
        rec_number: "#{rec_type}#{rec_num}"
      }
    else
      robot.logger.debug "No table_lookup entry for #{rec_type} records"
      res.send "I don't know how to look up #{rec_type} records"

  robot.respond /(?:sn(?:ow)?|service now) listen/i, (res) ->
    channel_id = res.message.room
    listen_brain = robot.brain.get("sn_api.#{channel_id}.listen")
    # handle scenario when variable is null
    if listen_brain?
      listen_toggle = !listen_brain
    else
      listen_toggle = true
    # persist the toggle state in the "brain"
    robot.brain.set "sn_api.#{channel_id}.listen", listen_toggle

    # generate a human-friendly string to describe the current state
    if listen_toggle
      listen_friendly = "will"
    else
      listen_friendly = "won't"
    res.send "I #{listen_friendly} listen for Service Now"

  # the record types we know about, and their table names
  table_lookup = {
    PRB: {
      table: 'problem',
      fields: {
        'short_description': 'Short Description',
        'assigned_to.name': 'Assigned to',
        'opened_by.name': 'Opened by',
        'opened_at': 'Opened at',
        'priority': 'Priority'
        'state': 'State'
      }
    }
    INC: {
      table: 'incident',
      fields: {
        'short_description': 'Short Description',
        'assigned_to.name': 'Assigned to',
        'opened_by.name': 'Opened by',
        'opened_at': 'Opened at',
        'priority': 'Priority'
        'state': 'State'
      }
    }
    CHG: {
      table: 'change_request'
      fields: {
        'short_description': 'Short Description',
        'cmdb_ci.name': 'CMDB CI',
        'assignment_group.name': 'Assignment group',
        'requested_by.name': 'Requested by',
        'start_date': 'Start Date',
        'end_date': 'End Date',
        'state': 'State'
      }
    }
    CTASK: {
      table: 'change_task'
      fields: {
        'short_description': 'Short Description',
        'change_request.number': 'Change Request',
        'cmdb_ci.name': 'CMDB CI',
        'assignment_group.name': 'Assignment group',
        'opened_by.name': 'Opened by',
        'opened_at': 'Opened at'
        'state': 'State'
      }
    }
    RITM: {
      table: 'sc_req_item'
      fields: {
        'short_description': 'Short Description',
        'assignment_group.name': 'Assignment group',
        'opened_by.name': 'Opened by',
        'opened_at': 'Opened At'
        'state': 'State'
      }
    }
    SCTASK: {
      table: 'sc_task'
      fields: {
        'short_description': 'Short Description',
        'request.number': 'Request',
        'request_item.number': 'Request Item',
        'request.requested_for.name': 'Requested For',
        'assignment_group.name': 'Assignment Group',
        'state': 'State'
      }
    }
  }

  # this works similar to the robot.respond message above,
  # but it looks only for the record types we know about
  # also, we need to be careful to avoid interaction with the normal
  # robot.respond messages, and we also don't want to create a feedback loop
  # between bots
  robot.hear ///(#{Object.keys(table_lookup).join('|')})([0-9]{7,})///i, (res) ->
    name_mention = "@#{robot.name}"
    start_with_mention = res.message.text.startsWith name_mention
    start_with_name = res.message.text.startsWith robot.name

    # don't do anything if bot was @ mentioned
    if start_with_mention or start_with_name
      robot.logger.debug "robot.hear ignoring explicit Service Now request " +
        " and allowing robot.respond to handle it"
      return

    # don't do anything if listen is false
    unless robot.brain.get("sn_api.#{res.message.room}.listen")
      robot.logger.debug "Ignoring Service Now request; sn listen is off"
      return

    # ignore messages from bots
    if res.message.user.is_bot or res.message.user.slack?.is_bot
      robot.logger.debug "Ignoring Service Now mention by bot"
      return

    rec_type = res.match[1]
    rec_num = res.match[2]

    robot.logger.debug "Record: #{rec_type}#{rec_num}"
    robot.logger.debug "user: #{res.message.user.name}"
    robot.logger.debug "table: #{table_lookup[rec_type]['table']}"
    robot.emit "sn_record_get", {
      user: res.message.user,
      table: table_lookup[rec_type]['table'],
      fields: table_lookup[rec_type]['fields']
      rec_number: "#{rec_type}#{rec_num}"
    }
