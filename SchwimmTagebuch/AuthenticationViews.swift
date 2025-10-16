import SwiftUI
import SwiftData

struct LoginView: View {
    @Environment(\.modelContext) private var context
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?
    @Query(sort: \AppUser.displayName) private var users: [AppUser]

    enum Field { case email, password }

    var onLogin: (AppUser) -> Void
    var onRegisterRequested: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Anmeldung") {
                    TextField("E-Mail", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                    SecureField("Passwort", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(action: attemptLogin) {
                        Label("Anmelden", systemImage: "lock.open")
                    }
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)

                    Button(role: .none) {
                        onRegisterRequested()
                    } label: {
                        Label("Neues Konto anlegen", systemImage: "person.badge.plus")
                    }
                }

                if !users.isEmpty {
                    Section("Vorhandene Benutzer") {
                        ForEach(users) { user in
                            Button {
                                email = user.email
                                focusedField = .password
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(user.displayName)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Anmelden")
        }
    }

    private func attemptLogin() {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            errorMessage = "Bitte eine E-Mail-Adresse eingeben."
            focusedField = .email
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Bitte ein Passwort eingeben."
            focusedField = .password
            return
        }

        var descriptor = FetchDescriptor<AppUser>(
            predicate: #Predicate<AppUser> { $0.email == normalizedEmail }
        )
        descriptor.fetchLimit = 1

        do {
            if let user = try context.fetch(descriptor).first,
               PasswordHasher.verify(password: password, storedHash: user.passwordHash) {
                errorMessage = nil
                onLogin(user)
            } else {
                errorMessage = "Anmeldedaten ungültig."
                password = ""
                focusedField = .password
            }
        } catch {
            errorMessage = "Anmeldung derzeit nicht möglich."
        }
    }
}

struct RegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    enum Field { case name, email, password, confirm }

    var onRegister: (AppUser) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Profil") {
                    TextField("Anzeigename", text: $displayName)
                        .textContentType(.name)
                        .focused($focusedField, equals: .name)
                    TextField("E-Mail", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                }

                Section("Sicherheit") {
                    SecureField("Passwort", text: $password)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                    SecureField("Passwort bestätigen", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirm)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(action: attemptRegistration) {
                        Label("Registrieren", systemImage: "checkmark.seal")
                    }
                    .disabled(!canRegister)
                }
            }
            .navigationTitle("Konto erstellen")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
    }

    private var canRegister: Bool {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return !normalizedEmail.isEmpty && !password.isEmpty && password == confirmPassword
    }

    private func attemptRegistration() {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            errorMessage = "Bitte eine gültige E-Mail angeben."
            focusedField = .email
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Das Passwort muss mindestens 6 Zeichen haben."
            focusedField = .password
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Die Passwörter stimmen nicht überein."
            confirmPassword = ""
            focusedField = .confirm
            return
        }

        var descriptor = FetchDescriptor<AppUser>(
            predicate: #Predicate<AppUser> { $0.email == normalizedEmail }
        )
        descriptor.fetchLimit = 1

        do {
            if try context.fetch(descriptor).first != nil {
                errorMessage = "Diese E-Mail wird bereits verwendet."
                focusedField = .email
                return
            }

            let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let user = AppUser(
                email: normalizedEmail,
                displayName: name.isEmpty ? normalizedEmail : name,
                passwordHash: PasswordHasher.hash(password)
            )
            context.insert(user)
            try context.save()
            errorMessage = nil
            onRegister(user)
            dismiss()
        } catch {
            errorMessage = "Registrierung fehlgeschlagen. Bitte erneut versuchen."
        }
    }
}
