# Description:
#   Service Now Record lookup
#
# Commands:
#   hubot <sn|snapi|service now> <record number> - Look up record number in Service Now
#   hubot <sn|snapi|service now> listen - Toggle Implicit/Explicit listening for Service Now records
#
# Configuration:
#   HUBOT_SERVICE_NOW_INSTANCE: Service Now instance (e.g. 'devtest' of devtest.service-now.com)
#   HUBOT_SERVICE_NOW_DOMAIN: Domain name for Serivce Now. defaults to service-now.com. Useful for using internal proxies
#   HUBOT_SERVICE_NOW_USER: Service Now API Username
#   HUBOT_SERVICE_NOW_PASSWORD: Service Now API Password


module.exports = (robot) ->
  ###
  The bit that does the work to ask Service Now for stuff is registered as an
  event so that you can consume this in other scripts if you'd like.
  The expected format of the 'request' object is as follows:
  request =
    sysparm_fields,
    sysparm_query,
    sysparm_limit,
    user

    The sysparm_fields, sysparm_query, and sysparm_limit strings are used in
    the Service Now query. The user object should be a room or user that the
    script can respond to if it runs into an error.
  ###
  robot.on "sn_api_get", (request) ->
    if process.env?.HUBOT_SERVICE_NOW_HOSTNAME?
      sn_domain = process.env.HUBOT_SERVICE_NOW_HOSTNAME
    else
      sn_domain = 'service-now.com'
    sn_uri = "https://#{process.env.HUBOT_SERVICE_NOW_INSTANCE}.#{sn_domain}"

###



  robot.on "sn_api_get", (request) ->
    fields = Object.keys(request.fields)
    robot.logger.debug "fields: #{fields}"
    sn_url = "https://snapi.lns.starwave.com/api/now/v2/table/\
#{request.table}?sysparm_query=number=#{request.number}\
&sysparm_fields=#{fields}"

    robot.logger.debug "SN URL: #{sn_url}"
    robot.http(sn_url)
      .header('Accept', 'application/json')
      .auth(process.env.HUBOT_SNAPI_USER, process.env.HUBOT_SNAPI_PASSWORD)
      .get() (err, res, body) ->
        if (err?)
          robot.send request.user "Error was encountered while looking for \
`#{request.number}`"
          robot.logger.error "Received error #{err} when looking for #{request.number}"
        else
          data = JSON.parse body
          result = data['result']
        if result?
          if (result.length < 1)
            robot.send request.user, "Service Now returned 0 records for \
'#{request.number}'"
          else
            if (result.length > 1)
              robot.send request.user, "Service Now returned multiple records. \
  Showing the first"
            robot.emit "sn_results_fmt", {
              user: request.user,
              fields: request.fields,
              number: request.number,
              record: result[0],
              table: request.table
            }
        else
          robot.send request.user, "Error was encountered while looking for \
`#{request.number}`"
          robot.logger.error "Received error '#{data.error.message}' while \
looking for '#{request.number}'"

  robot.on "sn_results_fmt", (result) ->
    output = "Found *#{result.number}:*"
    for k, v of result.fields
      continue if v == ''
      robot.logger.debug "Getting #{k} from result"
      output += "\n*#{v}:* #{result.record[k]}"

    robot.emit "get_state_print_output", {
      user: result.user
      output: output,
      table: result.table,
      state: result.record.state
    }

  robot.on "get_state_print_output", (record) ->
    # get state text
    sn_url = "https://snapi.lns.starwave.com/api/now/v2/table/sys_choice?sysparm_query=name=#{record.table}^element=state^value=#{record.state}^language=en"
    robot.logger.debug "state sn_url: #{sn_url}"
    robot.http(sn_url)
      .header('Accept', 'application/json')
      .auth(process.env.HUBOT_SNAPI_USER, process.env.HUBOT_SNAPI_PASSWORD)
      .get() (err, res, body) ->
        if (err?)
          robot.logger.debug "state got error from SNAPI: #{err}"
          state_text = ''
        else
          data = JSON.parse body
          label = data.result[0].label
          state_text = label

        robot.logger.debug "state_text: #{state_text}"
        output = record.output + "\n*State:* #{state_text}"

        robot.send record.user, output

  robot.respond /(?:sn(?:ow)?|service now) ([A-z]{3,5})([0-9]{7})/i, (res) ->
    rec_type = res.match[1]
    rec_num = res.match[2]

    if table_lookup[rec_type]?
      robot.logger.debug "Record: #{rec_type}#{rec_num}"
      robot.logger.debug "user: #{res.message.user.name}"
      robot.logger.debug "table: #{table_lookup[rec_type]['table']}"
      robot.emit "sn_api_get", {
        user: res.message.user,
        table: table_lookup[rec_type]['table'],
        fields: table_lookup[rec_type]['fields']
        number: "#{rec_type}#{rec_num}"
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
  table_lookup =
    PRB:
      table: 'problem',
      fields:
        'short_description': 'Short Description',
        'assigned_to.name': 'Assigned to',
        'opened_by.name': 'Opened by',
        'opened_at': 'Opened at',
        'priority': 'Priority'
        'state': ''
    INC:
      table: 'incident',
      fields:
        'short_description': 'Sort Description',
        'assigned_to.name': 'Assigned to',
        'opened_by.name': 'Opened by',
        'opened_at': 'Opened at',
        'priority': 'Priority'
        'state': ''
    CHG:
      table: 'change_request'
      fields:
        'short_description': 'Short Description',
        'cmdb_ci.name': 'CMDB CI',
        'assignment_group.name': 'Assignment group',
        'requested_by.name': 'Requested by',
        'opened_at': 'Opened At'
        'state': ''
    RITM:
      table: 'sc_req_item'
      fields:
        'short_description': 'Short Description',
        'assignment_group.name': 'Assignment group',
        'opened_by.name': 'Opened by',
        'opened_at': 'Opened At'
        'state': ''

  # this works similar to the robot.respond message above,
  # but it looks only for the record types we know about
  # also, we need to be careful to avoid interaction with the normal
  # robot.respond messages, and we also don't want to create a feedback loop
  # between bots
  robot.hear ///(#{Object.keys(table_lookup).join('|')})([0-9]{7})///i, (res) ->
    name_mention = "@#{robot.name}"
    start_with_mention = res.message.text.startsWith name_mention
    start_with_name = res.message.text.startsWith robot.name

    # don't do anything if bot was @ mentioned
    return if start_with_mention or start_with_name

    # don't do anything if listen is false
    return unless robot.brain.get("sn_api.#{res.message.room}.listen")

    # ignore messages from bots
    return if res.message.user.is_bot

    rec_type = res.match[1]
    rec_num = res.match[2]

    robot.logger.debug "Record: #{rec_type}#{rec_num}"
    robot.logger.debug "user: #{res.message.user.name}"
    robot.logger.debug "table: #{table_lookup[rec_type]['table']}"
    robot.emit "sn_api_get", {
      user: res.message.user,
      table: table_lookup[rec_type]['table'],
      fields: table_lookup[rec_type]['fields']
      number: "#{rec_type}#{rec_num}"
    }
