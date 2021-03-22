// https://github.com/Quick/Quick

import Quick
import Nimble
import Swamp


class TestSessionDelegate: SwampSessionDelegate {

    // For testing purposes
    var reasonEnded: String? = nil
    var sessionId: Int? = nil

    func handleChallenge(_ authMethod: String, extra: [String : Any]) -> String {
        fatalError("Should be overriden, if needed")
    }

    func sessionConnected(_ session: SwampSession, sessionId: Int) {
        self.sessionId = sessionId
    }

    func sessionEnded(_ reason: String) {
        self.reasonEnded = reason
    }
}

class CraTestSessionDelegate: TestSessionDelegate {
    fileprivate let craSecret: String
    init(craSecret: String) {
        self.craSecret = craSecret
    }

    override func handleChallenge(_ authMethod: String, extra: [String : Any]) -> String {
        return SwampCraAuthHelper.sign(self.craSecret, challenge: extra["challenge"] as! String)
    }
}

class TicketTestSessionDelegate: TestSessionDelegate {
    fileprivate let challengeResponse: String
    init(challengeResponse: String) {
        self.challengeResponse = challengeResponse
    }
    override func handleChallenge(_ authMethod: String, extra: [String : Any]) -> String {
        return self.challengeResponse
    }

}


class TestSwampTransport: SwampTransport {
    var delegate: SwampTransportDelegate?

    var dataSent: [NSData]

    init() {
        self.dataSent = []
    }

    func connect() {
        self.delegate?.didConnect(with: JSONSwampSerializer())
    }

    func disconnect(_ reason: String) {
        self.delegate?.didDisconnect(with: reason, code: 123)
    }

    func sendData(_ data: Data) {

    }
}

class CrossbarIntegrationTestsSpec: QuickSpec {

    var session: SwampSession?

    override func spec() {
        describe("the Open realm") { [self] in


            beforeEach {
                session = SwampSession(realm: "open-realm", transport: WebSocketSwampTransport(wsEndpoint: URL(string: "ws://localhost:8080/ws")!), authmethods: ["anonymous"])
            }

            context("Connecting to router") {
                it("Should connect successfully") {
                    session!.connect()
                    expect(session!.isConnected()).toEventually( beTrue() )
                }

                it("Should disconnect successfully") {
                    let testDelegate = TestSessionDelegate()
                    session!.delegate = testDelegate
                    session!.connect()
                    expect(session!.isConnected()).toEventually( beTrue() )
                    session!.disconnect()
                    expect(testDelegate.reasonEnded).toEventually( equal("wamp.close.normal") )
                }
            }

            context("Calling remote procedures") {
                beforeEach {
                    session!.connect()
                    expect(session!.isConnected()).toEventually( beTrue() )
                }

                context("org.swamp.add") {
                    it("Should return 1+1=2") {
                        waitUntil { done in
                            session!.call("org.swamp.add", args: [1, 1], onSuccess: { details, results, kwResults in
                                expect(results![0] as? Int) == 2
                                done()
                                }, onError: {a, b, c, d in})
                        }
                    }

                    it("Should fail with wrong amount of parameters") {
                        waitUntil { done in
                            session!.call("org.swamp.add", args: [1], onSuccess: { details, results, kwResults in

                                }, onError: { details, error, args, kwargs in
                                    done()
                            })
                        }
                    }
                }

                context("org.swamp.echo") {
                    it("Should echo 1,1") {
                        waitUntil { done in
                            session!.call("org.swamp.echo", args: [1, 1], onSuccess: { details, results, kwResults in
                                expect(results![0] as? [Int]) == [1, 1]
                                done()
                            }, onError: { details, error, args, kwargs in

                            })
                        }
                    }
                }
            }

            context("Subscribing on topics") {
                beforeEach {
                    session!.connect()
                    expect(session!.isConnected()).toEventually( beTrue() )
                }

                context("org.swamp.heartbeat") {
                    it("Should arrive within several seconds") {
                        var subscription: Subscription?
                        waitUntil(timeout: .seconds(3)) { done in
                            session!.subscribe("org.swamp.heartbeat", onSuccess: { subscription = $0 }, onError: { details, error in

                            }, onEvent: { details, results, kwResults in
                                expect(results![0] as? String) == "Heartbeat!"
                                // Important so done() is not called twice!
                                subscription!.cancel({ done() }, onError: { details, error in })
                            })
                        }
                    }
                }
            }

            context("Publishing events") {
                beforeEach {
                    session!.connect()
                    expect(session!.isConnected()).toEventually( beTrue() )
                }

                context("Unacknowledged publication") {
                    it("Should just run silently") {
                        session!.publish("org.swamp.some_publication", args: [1, 2, 3])
                    }
                }

                context("Acknowledged publication") {
                    it("Should succeed") {
                        waitUntil { done in
                            session!.publish("org.swamp.some_publication", args: [1, 2, 3], onSuccess: {
                                done()
                            }, onError: { details, error in
                                print(1)
                            })
                        }
                    }
                }
            }
        }

        describe("the Restrictive realm") {
            var session: SwampSession?

            beforeEach {
                session = SwampSession(realm: "restrictive-realm", transport: WebSocketSwampTransport(wsEndpoint: URL(string: "ws://127.0.0.1:8080/ws")!), authmethods: ["wampcra"], authid: "homer")
            }

            context("Connecting to router") {
                it("Should succeed with CRA authentication") {
                    let craDelegate = CraTestSessionDelegate(craSecret: "secret123")
                    session!.delegate = craDelegate
                    session!.connect()
                    expect(session!.isConnected()).toEventually( beTrue() )
                }

                it("Should fail with incorrect secret") {
                    let incorrectSecretCraDelegate = CraTestSessionDelegate(craSecret: "׳wrong-secret")
                    session!.delegate = incorrectSecretCraDelegate
                    session!.connect()
                    expect(incorrectSecretCraDelegate.reasonEnded).toEventually( equal("wamp.error.not_authorized") )
                }
            }
        }
    }
}
