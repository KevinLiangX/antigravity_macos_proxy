import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .notAuthenticated
    @Published var loginFlowState: LoginFlowState = .idle
    @Published var activeAccount: GoogleAccount?
    @Published var accounts: [GoogleAccount] = []
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var authURLString: String?
    @Published var isBusy = false

    private let oauthService: GoogleOAuthService

    init(oauthService: GoogleOAuthService = GoogleOAuthService()) {
        self.oauthService = oauthService
        reloadState(reinitialize: true, clearMessages: true)
    }

    func reloadState(reinitialize: Bool = false, clearMessages: Bool = false) {
        if reinitialize {
            oauthService.initialize()
        }

        authState = oauthService.getAuthStateInfo()
        let flow = oauthService.getLoginFlowInfo()
        loginFlowState = flow.state
        authURLString = flow.authURL?.absoluteString

        if clearMessages {
            statusMessage = nil
            errorMessage = nil
        }

        do {
            accounts = try oauthService.getAccounts()
            activeAccount = try oauthService.getActiveAccount()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func login() {
        guard !isBusy else {
            return
        }

        isBusy = true
        statusMessage = "正在启动 Google 登录..."
        errorMessage = nil

        Task {
            reloadState()
            do {
                _ = try await oauthService.login()
                statusMessage = "登录成功"
                isBusy = false
                reloadState()
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = nil
                isBusy = false
                reloadState()
            }
        }
    }

    func cancelLogin() {
        oauthService.cancelLogin()
        statusMessage = "已取消登录"
        errorMessage = nil
        isBusy = false
        reloadState()
    }

    func logout() {
        guard !isBusy else {
            return
        }

        isBusy = true
        Task {
            do {
                try oauthService.logout()
                statusMessage = "已登出"
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = nil
            }
            isBusy = false
            reloadState()
        }
    }

    func refreshAccessToken() {
        guard !isBusy else {
            return
        }

        isBusy = true
        statusMessage = "正在校验 Token..."
        errorMessage = nil

        Task {
            do {
                _ = try await oauthService.getValidAccessToken()
                statusMessage = "Token 有效"
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = nil
            }
            isBusy = false
            reloadState()
        }
    }

    var authStateText: String {
        switch authState {
        case .notAuthenticated:
            return "未登录"
        case .authenticating:
            return "登录中"
        case .authenticated:
            return "已登录"
        case .tokenExpired:
            return "Token 过期"
        case .refreshing:
            return "刷新中"
        case .error(let message):
            return "错误: \(message)"
        }
    }

    var loginFlowText: String {
        switch loginFlowState {
        case .idle:
            return "空闲"
        case .preparing:
            return "准备中"
        case .openingBrowser:
            return "打开浏览器"
        case .waitingAuthorization:
            return "等待授权"
        case .exchangingToken:
            return "交换 Token"
        case .success:
            return "成功"
        case .error:
            return "失败"
        case .cancelled:
            return "已取消"
        }
    }

    var activeAccountId: String? {
        activeAccount?.id
    }

    func switchActiveAccount(to accountId: String) {
        guard !isBusy else {
            return
        }

        isBusy = true
        errorMessage = nil

        Task {
            do {
                try oauthService.setActiveAccount(accountId)
                statusMessage = "已切换账户"
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = nil
            }
            isBusy = false
            reloadState()
        }
    }
}
