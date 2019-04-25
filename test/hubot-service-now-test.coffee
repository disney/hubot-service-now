Helper = require('hubot-test-helper')
chai = require 'chai'
nock = require('nock')
expect = chai.expect

helper = new Helper('../src/hubot-service-now.coffee')

process.env.HUBOT_SERVICE_NOW_INSTANCE = 'devtest'
process.env.HUBOT_SERVICE_NOW_USER = 'scotty'
process.env.HUBOT_SERVICE_NOW_PASSWORD = 'beammeup'

describe 'hubot-service-now', ->
  beforeEach ->
    @room = helper.createRoom({ httpd: false })

  afterEach ->
    nock.cleanAll()

  # define an object that can be used to simplify the testing process
  # each key should contain a record type to be tested;
  # the value contains the table that corresponds to the record type,
  # and a key/value pair for fields. The field key corresponds to the SN API
  # record field name, and the value is another key/value pair that contains
  # the human-readable name that's also used in the script, plus a value
  # used for testing (essentially, what the API would respond with)
  records = {
    RITM: {
      table: 'sc_req_item'
      fields: {
        short_description: {
          name: 'Short Description'
          value: 'Please locate the cheesburger'
        }
        "assignment_group.name": {
          name: 'Assignment group'
          value: 'cheesburger-recovery'
        }
        "opened_by.name": {
          name: 'Opened by'
          value: 'Bob Jones'
        }
        opened_at: {
          name: 'Opened At'
          value: '1970-01-01 01:00:00'
        }
        state: {
          name: 'State'
          value: 'In Progress'
        }
      }
    }
    SCTASK: {
      table: 'sc_task'
      fields: {
        short_description: {
          name: 'Short Description',
          value: 'Locate Cheeeburger Task'
        }
        "request.number": {
          name: 'Request',
          value: 'REQ0000001'
        }
        "request_item.number": {
          name: 'Request Item',
          value: 'RITM0000001'
        }
        "request.requested_for.name": {
          name: 'Requested For',
          value: 'Bob Jones'
        }
        "assignment_group.name": {
          name: 'Assignment Group',
          value: 'cheeseburger-recovery'
        }
        "state": {
          name: 'State'
          value: 'In Progress'
        }
      }
    }
    INC: {
      table: 'incident'
      fields: {
        short_description: {
          name: 'Short Description'
          value: 'Please locate the cheeseburger'
        }
        "assigned_to.name": {
          name: 'Assigned to'
          value: 'Jane Jones'
        }
        "opened_by.name": {
          name: 'Opened by'
          value: 'Bob Jones'
        }
        opened_at: {
          name: 'Opened at'
          value: '1970-01-01 01:00:00'
        }
        priority: {
          name: 'Priority'
          value: '1'
        }
        state: {
          name: 'State'
          value: '1 - Critical'
        }
      }
    }
    CHG: {
      table: 'change_request'
      fields: {
        short_description: {
          name: 'Short Description'
          value: 'Replace the cheeseburger'
        }
        "cmdb_ci.name": {
          name: 'CMDB CI'
          value: 'cheeseburger'
        }
        "assignment_group.name": {
          name: 'Assignment group'
          value: 'cheeseburger-replacement'
        }
        "requested_by.name": {
          name: 'Requested by'
          value: 'Jane Jones'
        }
        start_date: {
          name: 'Start Date'
          value: '1970-01-02 01:00:00'
        }
        end_date: {
          name: 'End Date'
          value: '1970-01-02 02:00:00'
        }
        state: {
          name: 'State'
          value: 'In Progress'
        }
      }
    }
    CTASK: {
      table: 'change_task'
      fields: {
        short_description: {
          name: 'Short Description'
          value: 'Put the cheeseburger on the table'
        }
        "change_request.number": {
          name: 'Change Request'
          value: 'CHG0000001'
        }
        "cmdb_ci.name": {
          name: 'CMDB CI'
          value: 'cheeseburger'
        }
        "assignment_group.name": {
          name: 'Assignment group'
          value: 'cheeseburger-replacement'
        }
        "opened_by.name": {
          name: 'Opened by'
          value: "cheeseburger-replacement"
        }
        opened_at: {
          name: 'Opened at'
          value: '1970-01-02 01:05:00'
        }
        state: {
          name: 'State'
          value: 'In Progress'
        }
      }
    }
    PRB: {
      table: 'problem'
      fields: {
        short_description: {
          name: 'Short Description'
          value: 'Hamburger keeps getting lost'
        }
        "assigned_to.name": {
          name: 'Assigned to',
          value: 'Jone Bobs'
        }
        "opened_by.name": {
          name: 'Opened by'
          value: "Bob Jones"
        }
        opened_at: {
          name: "Opened at"
          value: "1970-01-02 02:00:00"
        }
        priority: {
          name: 'Priority'
          value: '1 - Critical'
        }
        state: {
          name: 'State'
          value: 'Open'
        }
      }
    }
  }

  # actual tests start here
  context 'with sn listen previously disabled (default)', ->
    it 'doesn\'t respond to implict requests', ->
      @room.user.say('bob', 'Please do the needful with PRB0000001').then =>
        expect(@room.messages).to.eql [
          ['bob', 'Please do the needful with PRB0000001']
        ]

    it 'supports "sn listen" toggle on', ->
      @room.user.say('bob', '@hubot sn listen').then =>
        expect(@room.messages).to.eql [
          ['bob', '@hubot sn listen']
          ['hubot', 'I will listen for Service Now']
        ]
        expect(@room.robot.brain.get('sn_api.room1.listen')).to.eql true

  context 'with sn listen previously enabled', ->
    beforeEach ->
      @room.robot.brain.set 'sn_api.room1.listen', true

    it 'responds to implicit requests', ->
      # use INC record to test with
      k = 'INC'
      v = records[k]

      # generate mocked API result
      response_fields = {}
      for k1, v1 of v.fields
        response_fields[k1] = v1['value']
      request_fields = Object.keys(v.fields).concat(['sys_id'])

      nock('https://devtest.service-now.com')
        .get("/api/now/v2/table/#{v.table}")
        .query({
          sysparm_query: "number=#{k}0000001",
          sysparm_display_value: true,
          sysparm_limit: 1,
          sysparm_fields: request_fields.join(',')
        })
        .reply(200, {
          result: [
            response_fields
          ] }, {
            'X-Total-Count': 1
        })

      # generate the expected bot response
      response_message = "Found *#{k}0000001:*"
      for k1, v1 of v.fields
        response_message += "\n*#{v1['name']}:* #{v1['value']}"

      @room.user.say('bob', 'Please do the needful with INC0000001').then =>
        expect(@room.messages).to.eql [
          ['bob', 'Please do the needful with INC0000001']
          ['hubot', response_message]
        ]

    it 'supports "sn listen" toggle off', ->
      @room.user.say('bob', '@hubot sn listen').then =>
        expect(@room.messages).to.eql [
          ['bob', '@hubot sn listen']
          ['hubot', 'I won\'t listen for Service Now']
        ]
        expect(@room.robot.brain.get('sn_api.room1.listen')).to.eql false

  it 'logs useful message for records it doesn\'t know how to look up', ->
    @room.user.say('bob', '@hubot sn BOB0000001').then =>
      expect(@room.messages).to.eql [
        ['bob', '@hubot sn BOB0000001']
        ['hubot', 'I don\'t know how to look up BOB records']
      ]

  # loop over the supported record types and test each one of them
  for k, v of records
    do (k, v) ->
      it "handles #{k} record lookup", ->
        # generated mocked API response
        response_fields = {}
        for k1, v1 of v.fields
          response_fields[k1] = v1['value']
        request_fields = Object.keys(v.fields).concat(['sys_id'])

        # use nock to stub the response from the API call
        nock('https://devtest.service-now.com')
          .get("/api/now/v2/table/#{v.table}")
          .query({
            sysparm_query: "number=#{k}0000001",
            sysparm_display_value: true,
            sysparm_limit: 1,
            sysparm_fields: request_fields.join(',')
          })
          .reply(200, {
            result: [
              response_fields
            ] }, {
              'X-Total-Count': 1
          })

        # generate the expected bot response
        response_message = "Found *#{k}0000001:*"
        for k1, v1 of v.fields
          response_message += "\n*#{v1['name']}:* #{v1['value']}"
        @room.user.say('bob', "@hubot sn #{k}0000001").then =>
          expect(@room.messages).to.eql [
            ['bob', "@hubot sn #{k}0000001"]
            ['hubot', response_message]
          ]

  context 'when sys_id is supplied in sn_single_result_fmt event', ->
    it "adds hyperlink to service now in ticket response", ->
      # use nock to stub the response from the API call
      record = records['RITM']
      response_fields = {}
      for k1, v1 of record['fields']
        response_fields[k1] = v1['value']
      response_fields['sys_id'] = 'aaaaaaaaaaaaaaaaabbbcccc11223345'

      request_fields = Object.keys(record['fields']).concat(['sys_id'])

      nock('https://devtest.service-now.com')
        .get("/api/now/v2/table/#{record['table']}")
        .query({
          sysparm_query: "number=RITM0000001",
          sysparm_display_value: true,
          sysparm_limit: 1,
          sysparm_fields: request_fields.join(',')
        })
        .reply(200, {
          result: [
            response_fields
          ] }, {
            'X-Total-Count': 1
        })

      # generate the expected bot response
      slack_record_url = 'https://devtest.service-now.com/nav_to.do?uri=/sc_req_item.do?' +
        'sys_id=aaaaaaaaaaaaaaaaabbbcccc11223345'
      response_message = "Found *<#{slack_record_url}|RITM0000001>:*"
      for k, v of record.fields
        response_message += "\n*#{v['name']}:* #{v['value']}"
      @room.user.say('bob', "@hubot sn RITM0000001").then =>
        expect(@room.messages).to.eql [
          ['bob', "@hubot sn RITM0000001"]
          ['hubot', response_message]
        ]
  #
  context 'when incidents are over 10 million', ->
    it 'properly handles record lookup', ->
      # use INC record to test with
      k = 'INC'
      v = records[k]

      # generate mocked API result
      response_fields = {}
      for k1, v1 of v.fields
        response_fields[k1] = v1['value']
      request_fields = Object.keys(v.fields).concat(['sys_id'])

      nock('https://devtest.service-now.com')
        .get("/api/now/v2/table/#{v.table}")
        .query({
          sysparm_query: "number=#{k}00000001",
          sysparm_display_value: true,
          sysparm_limit: 1,
          sysparm_fields: request_fields.join(',')
        })
        .reply(200, {
          result: [
            response_fields
          ] }, {
            'X-Total-Count': 1
        })

      # generate the expected bot response
      response_message = "Found *#{k}00000001:*"
      for k1, v1 of v.fields
        response_message += "\n*#{v1['name']}:* #{v1['value']}"
      @room.user.say('bob', "@hubot sn #{k}00000001").then =>
        expect(@room.messages).to.eql [
          ['bob', "@hubot sn #{k}00000001"]
          ['hubot', response_message]
        ]
