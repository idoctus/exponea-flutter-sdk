//
//  ExponeaConfigurationParserSpec.swift
//  ExponeaTests
//

import Foundation
import Quick
import Nimble

@testable import ExponeaSDK
@testable import exponea

class ExponeaConfigurationParserSpec: QuickSpec {
    override func spec() {
        describe("parse") {
            let parser = ConfigurationParser()
            let fileData = TestUtil.loadFile("configuration")
            let jsonList = TestUtil.parseJsonList(fileData).map { $0 as! [String:Any?] }
            
            it("verify data") {
                expect(jsonList.count).to(equal(4))
            }
            
            it("emoty map") {
                let data = jsonList[0]
                do {
                    _ = try parser.parseConfig(data)
                    fail("Should throw error")
                } catch {
                    expect(error.localizedDescription).to(equal("Property projectToken is required."))
                }
            }
            
            it("minimal") {
                let data = jsonList[1]
                let config = try parser.parseConfig(data)
                
                let settings = config.projectSettings
                expect(settings.projectToken).to(equal("mock-project-token"))
                expect(settings.authorization).to(equal(.token("mock-auth-token")))
                expect(settings.baseUrl).to(equal(ExponeaSDK.Constants.Repository.baseUrl))
                
                let setup = config.flushingSetup
                expect(setup.maxRetries).to(equal(ExponeaSDK.Constants.Session.maxRetries))
                switch setup.mode {
                case .immediate:
                    break
                default:
                    fail("Default flushing mode must stay .immediate, got \(setup.mode)")
                }

                let sessionTracking = config.automaticSessionTracking
                expect(sessionTracking.enabled).to(equal(true))
                expect(sessionTracking.timeout).to(equal(ExponeaSDK.Constants.Session.defaultTimeout))
                
                let props = config.defaultProperties
                expect(props).to(beNil())
                
                let notifTracking = config.pushNotificationTracking
                expect(notifTracking.appGroup).to(equal(""))
                expect(notifTracking.requirePushAuthorization).to(equal(true))
                expect(notifTracking.isEnabled).to(equal(true))
                
                expect(config.allowDefaultCustomerProperties).to(beNil())
            }
            
            it("defaultSession") {
                let data = jsonList[2]
                let config = try parser.parseConfig(data)

                let settings = config.projectSettings
                expect(settings.projectToken).to(equal("mock-project-token"))
                expect(settings.authorization).to(equal(.token("mock-auth-token")))
                expect(settings.baseUrl).to(equal("http://mock.base.url.com"))
                expect(settings.projectMapping).to(equal([
                    EventType.banner: [
                        ExponeaSDK.ExponeaProject(
                            baseUrl: settings.baseUrl,
                            projectToken: "other-project-token",
                            authorization: .token("other-auth-token")
                        )
                    ]
                ]))

                let setup = config.flushingSetup
                expect(setup.maxRetries).to(equal(10))

                let sessionTracking = config.automaticSessionTracking
                expect(sessionTracking.enabled).to(equal(true))
                expect(sessionTracking.timeout).to(equal(60))

                let props = config.defaultProperties
                expect(props).notTo(beNil())
                let propsF = props!
                expect(propsF["string"]?.jsonValue).to(equal(.string("value")))
                expect(propsF["boolean"]?.jsonValue).to(equal(.bool(false)))
                expect(propsF["number"]?.jsonValue).to(equal(.double(3.14159)))
                expect(propsF["array"]?.jsonValue).to(equal(.array([.string("value1"), .string("value2")])))
                expect(propsF["object"]?.jsonValue).to(equal(.dictionary(["key": .string("value")])))

                let notifTracking = config.pushNotificationTracking
                expect(notifTracking.isEnabled).to(equal(true))
                expect(notifTracking.tokenTrackFrequency).to(equal(.daily))
                expect(notifTracking.appGroup).to(equal("mock-app-group"))
                expect(notifTracking.requirePushAuthorization).to(equal(false))
                expect(notifTracking.delegate).to(beNil())

                expect(config.allowDefaultCustomerProperties).to(equal(true))
                expect(config.regenerateDeviceIdOnAnonymize).to(equal(true))
            }

            it("full") {
                let data = jsonList[3]
                let config = try parser.parseConfig(data)
                
                let settings = config.projectSettings
                expect(settings.projectToken).to(equal("mock-project-token"))
                expect(settings.authorization).to(equal(.token("mock-auth-token")))
                expect(settings.baseUrl).to(equal("http://mock.base.url.com"))
                expect(settings.projectMapping).to(equal([
                    EventType.banner: [
                        ExponeaSDK.ExponeaProject(
                            baseUrl: settings.baseUrl,
                            projectToken: "other-project-token",
                            authorization: .token("other-auth-token")
                        )
                    ]
                ]))
                
                let setup = config.flushingSetup
                expect(setup.maxRetries).to(equal(10))
                
                let sessionTracking = config.automaticSessionTracking
                expect(sessionTracking.enabled).to(equal(true))
                expect(sessionTracking.timeout).to(equal(45))
                
                let props = config.defaultProperties
                expect(props).notTo(beNil())
                let propsF = props!
                expect(propsF["string"]?.jsonValue).to(equal(.string("value")))
                expect(propsF["boolean"]?.jsonValue).to(equal(.bool(false)))
                expect(propsF["number"]?.jsonValue).to(equal(.double(3.14159)))
                expect(propsF["array"]?.jsonValue).to(equal(.array([.string("value1"), .string("value2")])))
                expect(propsF["object"]?.jsonValue).to(equal(.dictionary(["key": .string("value")])))
                
                let notifTracking = config.pushNotificationTracking
                expect(notifTracking.isEnabled).to(equal(true))
                expect(notifTracking.tokenTrackFrequency).to(equal(.daily))
                expect(notifTracking.appGroup).to(equal("mock-app-group"))
                expect(notifTracking.requirePushAuthorization).to(equal(false))
                expect(notifTracking.delegate).to(beNil())

                expect(config.allowDefaultCustomerProperties).to(equal(true))
                expect(config.regenerateDeviceIdOnAnonymize).to(equal(true))

                switch setup.mode {
                case .manual:
                    break
                default:
                    fail("flushMode MANUAL must reach flushingSetup.mode, got \(setup.mode)")
                }
            }
        }

        // The flushing mode must be part of FlushingSetup so the SDK is BORN in
        // that mode. Applying the mode after configure() is too late: configure
        // auto-tracks installation/session_start and, while the mode is still
        // the default .immediate, each of those schedules a delayed flush that
        // a later mode change does not cancel — the anonymous cookie then
        // materializes server-side before the user ever logs in.
        describe("parseFlushingSetup") {
            let parser = ConfigurationParser()
            let baseData: [String: Any?] = [
                "projectToken": "mock-project-token",
                "authorizationToken": "mock-auth-token"
            ]

            func parseSetup(flushMode: String?) throws -> ExponeaSDK.Exponea.FlushingSetup {
                var data = baseData
                if let flushMode = flushMode {
                    data["flushMode"] = flushMode
                }
                return try parser.parseFlushingSetup(data)
            }

            it("defaults to immediate when flushMode is absent") {
                let setup = try parseSetup(flushMode: nil)
                switch setup.mode {
                case .immediate:
                    break
                default:
                    fail("Expected .immediate, got \(setup.mode)")
                }
            }

            it("parses MANUAL") {
                let setup = try parseSetup(flushMode: "MANUAL")
                switch setup.mode {
                case .manual:
                    break
                default:
                    fail("Expected .manual, got \(setup.mode)")
                }
            }

            it("parses IMMEDIATE") {
                let setup = try parseSetup(flushMode: "IMMEDIATE")
                switch setup.mode {
                case .immediate:
                    break
                default:
                    fail("Expected .immediate, got \(setup.mode)")
                }
            }

            it("parses PERIOD with the default period") {
                let setup = try parseSetup(flushMode: "PERIOD")
                switch setup.mode {
                case .periodic(let period):
                    expect(period).to(equal(FlushModeEncoder().defaultPeriod))
                default:
                    fail("Expected .periodic, got \(setup.mode)")
                }
            }

            it("parses APP_CLOSE as automatic") {
                let setup = try parseSetup(flushMode: "APP_CLOSE")
                switch setup.mode {
                case .automatic:
                    break
                default:
                    fail("Expected .automatic, got \(setup.mode)")
                }
            }

            it("throws on an unknown flushMode value") {
                expect { try parseSetup(flushMode: "NOT_A_MODE") }.to(throwError())
            }

            it("keeps flushMaxRetries parsing intact") {
                var data = baseData
                data["flushMode"] = "MANUAL"
                data["flushMaxRetries"] = 7
                let setup = try parser.parseFlushingSetup(data)
                expect(setup.maxRetries).to(equal(7))
            }

            it("parses the full ExponeaConfiguration with flushMode into flushingSetup") {
                var data = baseData
                data["flushMode"] = "MANUAL"
                let config = try parser.parseConfig(data)
                switch config.flushingSetup.mode {
                case .manual:
                    break
                default:
                    fail("Expected .manual, got \(config.flushingSetup.mode)")
                }
                // flushingMode mirrors flushingSetup.mode for plugin-side reads
                // (FlushingSetup.mode is internal to ExponeaSDK).
                switch config.flushingMode {
                case .manual:
                    break
                default:
                    fail("Expected .manual, got \(config.flushingMode)")
                }
            }

            it("defaults the full ExponeaConfiguration to immediate when flushMode is absent") {
                let config = try parser.parseConfig(baseData)
                switch config.flushingMode {
                case .immediate:
                    break
                default:
                    fail("Expected .immediate, got \(config.flushingMode)")
                }
            }
        }
    }
}
