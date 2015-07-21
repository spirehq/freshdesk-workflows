stream = require "readable-stream"
Promise = require "bluebird"
execAsync = Promise.promisify (require "child_process").exec
SaveUsers = require "../../../../../lib/Task/ActivityTask/Save/SaveUsers"
helpers = require "../../../../../core/test/helpers"
createUser = require "../../../../../lib/Model/User"

exec = (require "child_process").exec


describe "SaveUsers", ->
  knex = null; bookshelf = null; User = null; job = null; # shared between tests

  before (beforeDone) ->
    knex = helpers.createKnex()
    bookshelf = helpers.createBookshelf(knex)
    User = createUser(bookshelf)
    Promise.bind(@)
    .then -> knex.raw("SET search_path TO pg_temp")
    .then -> User.createTable()
    .nodeify beforeDone

  after (teardownDone) ->
    knex.destroy()
    .nodeify teardownDone

  beforeEach (setupDone) ->
#    execAsync "pg_tmp 2>/dev/null"
#    .spread (postgresUrl) ->
      job = new SaveUsers(
        avatarId: "wuXMSggRPPmW4FiE9"
      ,
        bookshelf: bookshelf
        input: new stream.PassThrough({objectMode: true})
        output: new stream.PassThrough({objectMode: true})
      )
      setupDone()
#    .nodeify(setupDone)

  it "should run", (testDone) ->
    job.execute()
    .then ->
      knex(User::tableName).count("id")
      .then (results) ->
        results[0].count.should.be.equal("1")
    .then ->
      User.where({id: 1}).fetch()
      .then (model) ->
        model.get("email").should.be.equal("example@example.com")
    .nodeify testDone
    job.input.write(
      id: 1
      email: "example@example.com"
      active: true
      deleted: true
      helpdesk_agent: false
      created_at: new Date()
      updated_at: new Date()
    )
    job.input.end()