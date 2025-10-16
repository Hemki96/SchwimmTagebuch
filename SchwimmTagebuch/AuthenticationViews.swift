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
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Willkommen zurück")
                            .font(.largeTitle.bold())
                        Text("Melde dich an, um dein Schwimmtraining im Blick zu behalten.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeaderLabel("Anmeldedaten", systemImage: "envelope")
                        TextField("E-Mail", text: $email)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.next)
                        SecureField("Passwort", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.go)
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .transition(.opacity)
                        }
                    }
                    .glassCard()
                    .tint(AppTheme.accent)

                    VStack(spacing: 12) {
                        Button(action: attemptLogin) {
                            Label("Anmelden", systemImage: "lock.open")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                        .tint(AppTheme.accent)

                        Button(role: .none) {
                            onRegisterRequested()
                        } label: {
                            Label("Neues Konto anlegen", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .glassCard()
                    .tint(AppTheme.accent)

                    if !users.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeaderLabel("Vorhandene Benutzer", systemImage: "person.3")
                            ForEach(users) { user in
                                Button {
                                    email = user.email
                                    focusedField = .password
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.displayName)
                                            .font(.body.weight(.semibold))
                                        Text(user.email)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(AppTheme.cardMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(AppTheme.glassStroke.opacity(0.7), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        .glassCard()
                        .tint(AppTheme.accent)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
                .onSubmit {
                    switch focusedField {
                    case .email:
                        focusedField = .password
                    default:
                        attemptLogin()
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Anmelden")
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.barMaterial, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .appSurfaceBackground()
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
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Neues Konto")
                            .font(.largeTitle.bold())
                        Text("Erstelle ein Profil, um deine Wettkämpfe und Trainings zu synchronisieren.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeaderLabel("Profil", systemImage: "person.crop.circle")
                        TextField("Anzeigename", text: $displayName)
                            .textContentType(.name)
                            .focused($focusedField, equals: .name)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.next)
                        TextField("E-Mail", text: $email)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.next)
                    }
                    .glassCard()
                    .tint(AppTheme.accent)

                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeaderLabel("Sicherheit", systemImage: "lock")
                        SecureField("Passwort", text: $password)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.next)
                        SecureField("Passwort bestätigen", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirm)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.go)
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .transition(.opacity)
                        }
                    }
                    .glassCard()
                    .tint(AppTheme.accent)

                    VStack(spacing: 12) {
                        Button(action: attemptRegistration) {
                            Label("Registrieren", systemImage: "checkmark.seal")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(!canRegister)
                    }
                    .glassCard()
                    .tint(AppTheme.accent)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
                .onSubmit {
                    switch focusedField {
                    case .name:
                        focusedField = .email
                    case .email:
                        focusedField = .password
                    case .password:
                        focusedField = .confirm
                    default:
                        if canRegister { attemptRegistration() }
                    }
                }
            }
            .navigationTitle("Konto erstellen")
            .scrollDismissesKeyboard(.interactively)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.barMaterial, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .appSurfaceBackground()
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
