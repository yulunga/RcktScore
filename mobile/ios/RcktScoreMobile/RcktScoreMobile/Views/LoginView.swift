import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("RcktScore")
                .font(.largeTitle.bold())

            Text("Organisation login")
                .foregroundStyle(.secondary)

            TextField("Username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(action: submit) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Sign in")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || username.isEmpty || password.isEmpty)
        }
        .padding()
    }

    private func submit() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let session = try await container.apiClient.login(username: username, password: password)
                container.sessionStore.save(session)
            } catch {
                errorMessage = (error as? APIErrorResponse)?.message ?? "Unable to sign in."
            }
            isLoading = false
        }
    }
}
