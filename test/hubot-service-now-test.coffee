Helper = require('hubot-test-helper')
chai = require 'chai'

expect = chai.expect

helper = new Helper('../src/hubot-service-now.coffee')

process.env.HUBOT_SERVICE_NOW_INSTANCE = 'devtest'
process.env.HUBOT_SERVICE_NOW_USER = 'scotty'
process.env.HUBOT_SERVICE_NOW_PASSWORD = 'beammeup'

describe 'hubot-service-now', ->
  beforeEach ->
    @room = helper.createRoom()

  afterEach ->
    @room.destroy()

  it 'supports "sn listen" toggle on"', ->
    @room.user.say('bob', '@hubot sn listen').then =>
      expect(@room.messages).to.eql [
        ['bob', '@hubot sn listen']
        ['hubot', 'I will listen for Service Now']
      ]
      expect(@room.robot.brain.get('sn_api.room1.listen')).to.eql true

  it 'supports "sn listen" toggle off', ->
    @room.robot.brain.set 'sn_api.room1.listen', true
    @room.user.say('bob', '@hubot sn listen').then =>
      expect(@room.messages).to.eql [
        ['bob', '@hubot sn listen']
        ['hubot', 'I won\'t listen for Service Now']
      ]
      expect(@room.robot.brain.get('sn_api.room1.listen')).to.eql false
