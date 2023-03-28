import Foundation

class UserStorage {
    private static let usernameKey = "usernameKey"
    private static let readerModeKey = "readermodekey"
    private static let internalSafariKey = "internalSafariKey"

    @Storage(key: readerModeKey, defaultValue: false) public static var readerMode: Bool
    @Storage(key: internalSafariKey, defaultValue: false) public static var internalSafariMode: Bool
    @Storage(key: usernameKey, defaultValue: nil) public static var loggedInUser: String?
    
    static var isLoggedIn: Bool {
        if HTTPCookieStorage.shared.cookies != nil && loggedInUser != nil { return true }
        return false
    }

    static func logOut() {
        loggedInUser = ""
        guard let cookies = HTTPCookieStorage.shared.cookies else { return }
        
        cookies.forEach { cookie in
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}
