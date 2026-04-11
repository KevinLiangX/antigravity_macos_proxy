import Foundation

struct ProxyConfig: Codable, Equatable {
    struct Proxy: Codable, Equatable {
        var host: String
        var port: Int
        var type: String
    }

    struct FakeIP: Codable, Equatable {
        var enabled: Bool
        var cidr: String
    }

    var logLevel: String
    var proxy: Proxy
    var fakeIP: FakeIP

    enum CodingKeys: String, CodingKey {
        case logLevel = "log_level"
        case proxy
        case fakeIP = "fake_ip"
    }

    static let `default` = ProxyConfig(
        logLevel: "warn",
        proxy: .init(host: "127.0.0.1", port: 7897, type: "socks5"),
        fakeIP: .init(enabled: true, cidr: "198.18.0.0/15")
    )
}
