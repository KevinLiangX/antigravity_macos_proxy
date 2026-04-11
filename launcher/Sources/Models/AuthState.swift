import Foundation

enum AuthState: Equatable {
    case notAuthenticated
    case authenticating
    case authenticated
    case tokenExpired
    case refreshing
    case error(String)
}
