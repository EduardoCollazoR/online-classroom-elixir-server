const assert = require('assert')
const WebSocket = require('ws')

let receive
let ws

const serverURL = "ws://overcoded.tk:8500"
const local = "ws://localhost:8500"

describe('Classroom', () => {

  before(() => {
    ws = new WebSocket(serverURL, {
      perMessageDeflate: false
    })
  })

  describe('Guest', () => {

    it('should send init data when connected', (done) => {
      ws.once('message', data => {
        assert.equal(JSON.parse(data).type, "init")
        done()
      })
    })

    it('should reject logout', (done) => {
      expected(
        {type: "logout"},
        "unexpected",
        done
      )
    })

    it('should reject create class', (done) => {
      expected(
        {type: "create_class", class_name: "test"},
        "unexpected",
        done
      )
    })

    it('should reject get created class', (done) => {
      expected(
        {type: "get_created_class"},
        "unexpected",
        done
      )
    })

    it('should reject subscribe class', (done) => {
      expected(
        {type:"subscribe_class", owner: "admin",class_name: "class1"},
        "unexpected",
        done
      )
    })

    it('should reject get subscribed classroom', (done) => {
      expected(
        {type:"get_subscribed_class"},
        "unexpected",
        done
      )
    })

    it('should reject unsubscribe classroom', (done) => {
      expected(
        {type:"unsubscribe_class", owner: "owner", class_name: "class1"},
        "unexpected",
        done
      )
    })

    it('should reject invalid login', (done) => {
      expected(
        {type:"login", username: "invalid", password: "invalid"},
        "login_failed",
        done
      )
    })

    it('should accept valid login', (done) => {
      expected(
        {type:"login", username: "test", password: "test"},
        "login_success",
        done
      )
    })

  })

  describe('User', () => {

    it('should reject leave_class when not in a class', (done) => {
      expected(
        {type: "leave_class", owner: "test", class_name: "test"},
        "unexpected",
        done
      )
    })

    it('should reject starting a non created class', (done) => {
      expected(
        {type: "start_class", class_name: "test"},
        "start_class failed",
        done
      )
    })

    it('should reject joining a not created class', (done) => {
      expected(
        {type:"join_class", owner: "test", class_name: "test"},
        "join_class failed",
        done
      )
    })

    it('should accept create_class', (done) => {
      expected(
        {type: "create_class", class_name: "test"},
        "create_class_success",
        done
      )
    })

    // it('should reject joining a not started class', (done) => {
    //   expected(
    //     {type:"join_class", owner: "test", class_name: "test"},
    //     "join_class test failed",
    //     done
    //   )
    // })

    it('should reject creating a created class', (done) => {
      expected(
        {type: "create_class", class_name: "test"},
        "create_class_failed",
        done
      )
    })

    it('should accept start_class', (done) => {
      expected(
        {type: "start_class", class_name: "test"},
        "start_class success",
        done
      )
    })

    it('should reject starting a started class', (done) => {
      expected(
        {type: "start_class", class_name: "test"},
        "start_class failed",
        done
      )
    })

    it('should accept join_class', (done) => {
      expected(
        {type:"join_class", owner: "test", class_name: "test"},
        "join_class success",
        done
      )
    })

    it('should reject joining a joined class', (done) => {
      expected(
        {type:"join_class", owner: "test", class_name: "test"},
        "join_class failed",
        done
      )
    })

    it('should accept leave_class', (done) => {
      expected(
        {type: "leave_class", owner: "test", class_name: "test"},
        "leave_class success",
        done
      )
    })

    it('should accept logout', (done) => {
      expected(
        {type:"logout"},
        "logout_success",
        done
      )
    })

    it('should reject logout when logouted', (done) => {
      expected(
        {type:"logout"},
        "unexpected",
        done
      )
    })

    // it('should ', (done) => {
    //   expected(
    //     {},
    //     "",
    //     done
    //   )

  })
})

function expected(message, expected, done) {
  ws.send(JSON.stringify(message))
  ws.once('message', data => {
    try {
      assert.equal(JSON.parse(data).type, expected)
      done()
    }
    catch (e) {
      done(e)
    }
  })
}
