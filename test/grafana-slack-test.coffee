Helper = require('hubot-test-helper')
chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
nock = require('nock')

helper = new Helper('./../src/grafana.coffee')

expect = chai.expect

room = null

before ->
  matchesBlanket = (path) -> path.match /node_modules\/blanket/
  runningTestCoverage = Object.keys(require.cache).filter(matchesBlanket).length > 0
  if runningTestCoverage
    require('require-dir')("#{__dirname}/../src", {recurse: true, duplicates: true})

setupRoomAndRequestGraph = (done) ->
  room = helper.createRoom({name: 'grafana'})
  @robot =
    respond: sinon.spy()
    hear: sinon.spy()

  require('../src/grafana')(@robot)

  setTimeout done, 100
  room.user.say 'alice', 'hubot graf db monitoring-default:network server=ww3.example.com now-6h'

describe 'Slack enabled', ->

  beforeEach ->
    process.env.HUBOT_GRAFANA_HOST = 'http://play.grafana.org'
    process.env.HUBOT_GRAFANA_SLACK_TOKEN='9999999999999999999999'
    process.env.HUBOT_GRAFANA_API_KEY='xxxxxxxxxxxxxxxxxxxxxxxxx'
    do nock.disableNetConnect

    nock('http://play.grafana.org')
      .get('/api/dashboards/db/monitoring-default')
      .replyWithFile(200, __dirname + '/fixtures/dashboard-monitoring-default.json')

    nock('http://play.grafana.org')
      .get('/render/dashboard-solo/db/monitoring-default/?panelId=7&width=1000&height=500&from=now-6h&to=now&var-server=ww3.example.com')
      .replyWithFile(200, __dirname + '/fixtures/dashboard-monitoring-default.png')

  afterEach ->
    room.destroy()
    nock.cleanAll()
    delete process.env.HUBOT_GRAFANA_HOST
    delete process.env.HUBOT_GRAFANA_SLACK_TOKEN
    delete process.env.HUBOT_GRAFANA_API_KEY

  context 'standard file upload', ->
    beforeEach (done) ->
      nock('https://slack.com')
        .filteringRequestBody((body) -> return '*')
        .filteringPath((path) -> return '/')
        .post('/')
        .replyWithFile(200, __dirname + '/fixtures/slack-upload.json')

      setupRoomAndRequestGraph(done)

    it 'should respond with a png graph in the default s3 region', ->
      expect(room.messages[0]).to.eql( [ 'alice', 'hubot graf db monitoring-default:network server=ww3.example.com now-6h' ] )
