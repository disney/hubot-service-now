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
    @room = helper.createRoom(httpd: false)

  afterEach ->
    nock.cleanAll()

  # define an object that can be used to simplify the testing process
  # each key should contain a record type to be tested;
  # the value contains the table that corresponds to the record type,
  # and a key/value pair for fields. The field key corresponds to the SN API
  # record field name, and the value is another key/value pair that contains
  # the human-readable name that's also used in the script, plus a value
  # used for testing (essentially, what the API would respond with)
  records =
    RITM:
      table: 'sc_req_item'
      fields:
        short_description:
          name: 'Short Description'
          value: 'Please locate the cheesburger'
        "assignment_group.name":
          name: 'Assignment group'
          value: 'cheesburger-recovery'
        "opened_by.name":
          name: 'Opened by'
          value: 'Bob Jones'
        opened_at:
          name: 'Opened At'
          value: '1970-01-01 01:00:00'
        state:
          name: 'State'
          value: 'In Progress'
    INC:
      table: 'incident'
      fields:
        short_description:
          name: 'Short Description'
          value: 'Please locate the cheeseburger'
        "assigned_to.name":
          name: 'Assigned to'
          value: 'Jane Jones'
        "opened_by.name":
          name: 'Opened by'
          value: 'Bob Jones'
        opened_at:
          name: 'Opened at'
          value: '1970-01-01 01:00:00'
        priority:
          name: 'Priority'
          value: '1'
        state:
          name: 'State'
          value: '1 - Critical'
    CHG:
      table: 'change_request'
      fields:
        short_description:
          name: 'Short Description'
          value: 'Replace the cheeseburger'
        "cmdb_ci.name":
          name: 'CMDB CI'
          value: 'cheeseburger'
        "assignment_group.name":
          name: 'Assignment group'
          value: 'cheeseburger-replacement'
        "requested_by.name":
          name: 'Requested by'
          value: 'Jane Jones'
        opened_at:
          name: 'Opened At'
          value: '1970-01-02 01:00:00'
        state:
          name: 'State'
          value: 'In Progress'
    PRB:
      table: 'problem'
      fields:
        short_description:
          name: 'Short Description'
          value: 'Hamburger keeps getting lost'
        "assigned_to.name":
          name: 'Assigned to',
          value: 'Jone Bobs'
        "opened_by.name":
          name: 'Opened by'
          value: "Bob Jones"
        opened_at:
          name: "Opened at"
          value: "1970-01-02 02:00:00"
        priority:
          name: 'Priority'
          value: '1 - Critical'
        state:
          name: 'State'
          value: 'Open'

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

      nock('https://devtest.service-now.com')
        .get("/api/now/v2/table/#{v.table}")
        .query(
          sysparm_query: "number=#{k}0000001",
          sysparm_display_value: true,
          sysparm_limit: 1,
          sysparm_fields: Object.keys(v.fields).join(',')
        )
        .reply(200, {
          result: [
            response_fields
          ]}, {
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

        # use nock to stub the response from the API call
        nock('https://devtest.service-now.com')
          .get("/api/now/v2/table/#{v.table}")
          .query(
            sysparm_query: "number=#{k}0000001",
            sysparm_display_value: true,
            sysparm_limit: 1,
            sysparm_fields: Object.keys(v.fields).join(',')
          )
          .reply(200, {
            result: [
              response_fields
            ]}, {
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
