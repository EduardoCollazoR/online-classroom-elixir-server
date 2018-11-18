const assert = require('assert')
const WebSocket = require('ws')

let receive
let ws

describe('Classroom', () => {

  before(() => {
    ws = new WebSocket("ws://localhost:8500", {
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
        {type:"login", username: "dev", password: "dev"},
        "login_success",
        done
      )
    })

  })

  describe('User', () => {

    it('should acc', () => {
      ws.once('message', data => {
        assert.equal(JSON.parse(data).type, "init")
      })
    })
})

function expected(message, expected, done) {
  ws.send(JSON.stringify(message))
  ws.once('message', data => {
    assert.equal(JSON.parse(data).type, expected)
    done()
  })
}
