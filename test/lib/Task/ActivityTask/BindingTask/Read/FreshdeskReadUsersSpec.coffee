_ = require "underscore"
Promise = require "bluebird"
stream = require "readable-stream"
input = require "../../../../../../core/test-helper/input"
createDependencies = require "../../../../../../core/helper/dependencies"
settings = (require "../../../../../../core/helper/settings")("#{process.env.ROOT_DIR}/settings/test.json")

FreshdeskReadUsers = require "../../../../../../lib/Task/ActivityTask/BindingTask/Read/FreshdeskReadUsers"

describe "FreshdeskReadUsers", ->
  dependencies = createDependencies(settings, "FreshdeskReadUsers")
  mongodb = dependencies.mongodb;

  Credentials = mongodb.collection("Credentials")
  Commands = mongodb.collection("Commands")
  Issues = mongodb.collection("Issues")

  task = null;

  before ->

  beforeEach ->
    task = new FreshdeskReadUsers(
      _.defaults
        params: {}
      , input
    ,
      activityId: "FreshdeskReadUsers"
    ,
      in: new stream.Readable({objectMode: true})
      out: new stream.PassThrough({objectMode: true})
    ,
      dependencies
    )
    Promise.bind(@)
    .then ->
      Promise.all [
        Credentials.remove()
        Commands.remove()
        Issues.remove()
      ]
    .then ->
      Promise.all [
        Credentials.insert
          avatarId: task.avatarId
          api: "Freshdesk"
          scopes: ["*"]
          details: settings.credentials["Freshdesk"]["Generic"]
        Commands.insert
          _id: input.commandId
          progressBars: [
            activityId: "FreshdeskReadUsers", isStarted: true, isCompleted: false, isFailed: false
          ]
          isStarted: true, isCompleted: false, isFailed: false
      ]

  afterEach ->

  it "should run", ->
    @timeout(10000) if process.env.NOCK_BACK_MODE is "record"
    new Promise (resolve, reject) ->
      nock.back "test/fixtures/FreshdeskReadUsers/normal.json", (recordingDone) ->
        sinon.spy(task.out, "write")
        sinon.spy(task.binding, "request")
        task.execute()
        .then ->
          task.binding.request.should.have.callCount(20)
          task.out.write.should.have.callCount(934)
          task.out.write.should.always.have.been.calledWithMatch sinon.match (object) ->
            object.hasOwnProperty("email")
          , "Object has own property \"email\""
        .then ->
          Commands.findOne(input.commandId)
          .then (command) ->
            command.progressBars[0].total.should.be.equal(0)
            command.progressBars[0].current.should.be.equal(934)
        .then resolve
        .catch reject
        .finally recordingDone

  testgc = (func) ->
    global.gc()
    leakCounter = 0
    trials = [1..20] # 10 isn't enough, as memory usage actually decreases during first runs
    Promise.reduce trials, (previousRss) ->
      func()
      .then ->
        global.gc()
        currentRss = process.memoryUsage().rss
        if currentRss > previousRss
          leakCounter++
          currentRss
        else
          previousRss
    , process.memoryUsage().rss
    .then (rssStats) ->
      if leakCounter > trials.length / 3
        throw new Error("Leak counter has been incremented #{leakCounter} times")

  it "should report a leak for bad code", ->
    new Promise (resolve, reject) ->
      leaksink = []
      leaker = ->
        Promise.bind(@)
        .then -> leaksink.push [1..100000]
      # we expect the error
      testgc(leaker)
      .then -> reject(new Error("No error was thrown"))
      .catch -> resolve()

  it "shouldn't report a leak for good code", ->

  it "shouldn't leak memory @gc", ->
#    @timeout(10000) if process.env.NOCK_BACK_MODE is "record"
#    testgc ->
#      new Promise (resolve, reject) ->
#        nock.back "test/fixtures/FreshdeskReadUsers/normal.json", (recordingDone) ->
#          sinon.spy(task.out, "write")
#          sinon.spy(task.binding, "request")
#          task.execute()
#          .then resolve
#          .catch reject
#          .finally recordingDone
#      task = new FreshdeskReadUsers(
#        _.defaults
#          params: {}
#        , input
#      ,
#        activityId: "FreshdeskReadUsers"
#      ,
#        in: new stream.Readable({objectMode: true})
#        out: new stream.Writable({objectMode: true})
#      ,
#        dependencies
#      )
