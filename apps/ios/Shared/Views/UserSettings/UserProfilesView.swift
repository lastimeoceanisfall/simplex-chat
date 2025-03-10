//
// Created by Avently on 17.01.2023.
// Copyright (c) 2023 SimpleX Chat. All rights reserved.
//

import SwiftUI
import SimpleXChat

struct UserProfilesView: View {
    @EnvironmentObject private var m: ChatModel
    @Environment(\.editMode) private var editMode
    @AppStorage(DEFAULT_PERFORM_LA) private var prefPerformLA = false
    @AppStorage(DEFAULT_SHOW_HIDDEN_PROFILES_NOTICE) private var showHiddenProfilesNotice = true
    @AppStorage(DEFAULT_SHOW_MUTE_PROFILE_ALERT) private var showMuteProfileAlert = true
    @State private var showDeleteConfirmation = false
    @State private var userToDelete: User?
    @State private var alert: UserProfilesAlert?
    @State private var authorized = !UserDefaults.standard.bool(forKey: DEFAULT_PERFORM_LA)
    @State private var searchTextOrPassword = ""
    @State private var selectedUser: User?
    @State private var profileHidden = false
    @State private var profileAction: UserProfileAction?
    @State private var actionPassword = ""

    var trimmedSearchTextOrPassword: String { searchTextOrPassword.trimmingCharacters(in: .whitespaces)}

    private enum UserProfilesAlert: Identifiable {
        case deleteUser(user: User, delSMPQueues: Bool)
        case cantDeleteLastUser
        case hiddenProfilesNotice
        case muteProfileAlert
        case activateUserError(error: String)
        case error(title: LocalizedStringKey, error: LocalizedStringKey = "")

        var id: String {
            switch self {
            case let .deleteUser(user, delSMPQueues): return "deleteUser \(user.userId) \(delSMPQueues)"
            case .cantDeleteLastUser: return "cantDeleteLastUser"
            case .hiddenProfilesNotice: return "hiddenProfilesNotice"
            case .muteProfileAlert: return "muteProfileAlert"
            case let .activateUserError(err): return "activateUserError \(err)"
            case let .error(title, _): return "error \(title)"
            }
        }
    }

    private enum UserProfileAction: Identifiable {
        case deleteUser(user: User, delSMPQueues: Bool)
        case unhideUser(user: User)

        var id: String {
            switch self {
            case let .deleteUser(user, delSMPQueues): return "deleteUser \(user.userId) \(delSMPQueues)"
            case let .unhideUser(user): return "unhideUser \(user.userId)"
            }
        }
    }

    var body: some View {
        if authorized {
            userProfilesView()
        } else {
            Button(action: runAuth) { Label("Unlock", systemImage: "lock") }
            .onAppear(perform: runAuth)
        }
    }

    private func runAuth() { authorize(NSLocalizedString("Open user profiles", comment: "authentication reason"), $authorized) }

    private func userProfilesView() -> some View {
        List {
            if profileHidden {
                Button {
                    withAnimation { profileHidden = false }
                } label: {
                    Label("Enter password above to show!", systemImage: "lock.open")
                }
            }
            Section {
                let users = filteredUsers()
                ForEach(users) { u in
                    userView(u.user)
                }
                .onDelete { indexSet in
                    if let i = indexSet.first {
                        if m.users.count > 1 && (m.users[i].user.hidden || visibleUsersCount > 1) {
                            showDeleteConfirmation = true
                            userToDelete = users[i].user
                        } else {
                            alert = .cantDeleteLastUser
                        }
                    }
                }

                if trimmedSearchTextOrPassword == "" {
                    NavigationLink {
                        CreateProfile()
                    } label: {
                        Label("Add profile", systemImage: "plus")
                    }
                    .frame(height: 44)
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("Tap to activate profile.")
                    .font(.body)
                    .padding(.top, 8)

            }
        }
        .toolbar { EditButton() }
        .navigationTitle("Your chat profiles")
        .searchable(text: $searchTextOrPassword, placement: .navigationBarDrawer(displayMode: .always))
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
        .onAppear {
            if showHiddenProfilesNotice && m.users.count > 1 {
                alert = .hiddenProfilesNotice
            }
        }
        .confirmationDialog("Delete chat profile?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            deleteModeButton("Profile and server connections", true)
            deleteModeButton("Local profile data only", false)
        }
        .sheet(item: $selectedUser) { user in
            HiddenProfileView(user: user, profileHidden: $profileHidden)
        }
        .onChange(of: profileHidden) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                withAnimation { profileHidden = false }
            }
        }
        .sheet(item: $profileAction) { action in
            profileActionView(action)
        }
        .alert(item: $alert) { alert in
            switch alert {
            case let .deleteUser(user, delSMPQueues):
                return Alert(
                    title: Text("Delete user profile?"),
                    message: Text("All chats and messages will be deleted - this cannot be undone!"),
                    primaryButton: .destructive(Text("Delete")) {
                        Task { await removeUser(user, delSMPQueues, viewPwd: userViewPassword(user)) }
                    },
                    secondaryButton: .cancel()
                )
            case .cantDeleteLastUser:
                return Alert(
                    title: Text("Can't delete user profile!"),
                    message: m.users.count > 1
                            ? Text("There should be at least one visible user profile.")
                            : Text("There should be at least one user profile.")
                )
            case .hiddenProfilesNotice:
                return Alert(
                    title: Text("Make profile private!"),
                    message: Text("You can hide or mute a user profile - swipe it to the right.\nSimpleX Lock must be enabled."),
                    primaryButton: .default(Text("Don't show again")) {
                        showHiddenProfilesNotice = false
                    },
                    secondaryButton: .default(Text("Ok"))
                )
            case .muteProfileAlert:
                return Alert(
                    title: Text("Muted when inactive!"),
                    message: Text("You will still receive calls and notifications from muted profiles when they are active."),
                    primaryButton: .default(Text("Don't show again")) {
                        showMuteProfileAlert = false
                    },
                    secondaryButton: .default(Text("Ok"))
                )
            case let .activateUserError(error: err):
                return Alert(
                    title: Text("Error switching profile!"),
                    message: Text(err)
                )
            case let .error(title, error):
                return Alert(title: Text(title), message: Text(error))
            }
        }
    }

    private func filteredUsers() -> [UserInfo] {
        let s = trimmedSearchTextOrPassword
        let lower = s.localizedLowercase
        return m.users.filter { u in
            if (u.user.activeUser || !u.user.hidden) && (s == "" || u.user.chatViewName.localizedLowercase.contains(lower)) {
                return true
            }
            return correctPassword(u.user, s)
        }
    }

    private var visibleUsersCount: Int {
        m.users.filter({ u in !u.user.hidden }).count
    }

    private func correctPassword(_ user: User, _ pwd: String) -> Bool {
        if let ph = user.viewPwdHash {
            return pwd != "" && chatPasswordHash(pwd, ph.salt) == ph.hash
        }
        return false
    }

    private func userViewPassword(_ user: User) -> String? {
        !user.hidden ? nil : trimmedSearchTextOrPassword
    }

    @ViewBuilder private func profileActionView(_ action: UserProfileAction) -> some View {
        let passwordValid = actionPassword == actionPassword.trimmingCharacters(in: .whitespaces)
        let passwordField = PassphraseField(key: $actionPassword, placeholder: "Profile password", valid: passwordValid)
        let actionEnabled: (User) -> Bool = { user in actionPassword != "" && passwordValid && correctPassword(user, actionPassword) }
        List {
            switch action {
            case let .deleteUser(user, delSMPQueues):
                actionHeader("Delete profile", user)
                Section {
                    passwordField
                    settingsRow("trash") {
                        Button("Delete chat profile", role: .destructive) {
                            profileAction = nil
                            Task { await removeUser(user, delSMPQueues, viewPwd: actionPassword) }
                        }
                        .disabled(!actionEnabled(user))
                    }
                } footer: {
                    if actionEnabled(user) {
                        Text("All chats and messages will be deleted - this cannot be undone!")
                            .font(.callout)
                    }
                }
            case let .unhideUser(user):
                actionHeader("Unhide profile", user)
                Section {
                    passwordField
                    settingsRow("lock.open") {
                        Button("Unhide chat profile") {
                            profileAction = nil
                            setUserPrivacy(user) { try await apiUnhideUser(user.userId, viewPwd: actionPassword) }
                        }
                        .disabled(!actionEnabled(user))
                    }
                }
            }
        }
    }

    @ViewBuilder func actionHeader(_ title: LocalizedStringKey, _ user: User) -> some View {
        Text(title)
            .font(.title)
            .bold()
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
        Section() {
            ProfilePreview(profileOf: user).padding(.leading, -8)
        }
    }

    private func deleteModeButton(_ title: LocalizedStringKey, _ delSMPQueues: Bool) -> some View {
        Button(title, role: .destructive) {
            if let user = userToDelete {
                if passwordEntryRequired(user) {
                    profileAction = .deleteUser(user: user, delSMPQueues: delSMPQueues)
                } else {
                    alert = .deleteUser(user: user, delSMPQueues: delSMPQueues)
                }
            }
        }
    }

    private func passwordEntryRequired(_ user: User) -> Bool {
        user.hidden && user.activeUser && !correctPassword(user, trimmedSearchTextOrPassword)
    }

    private func removeUser(_ user: User, _ delSMPQueues: Bool, viewPwd: String?) async {
        do {
            if user.activeUser {
                if let newActive = m.users.first(where: { u in !u.user.activeUser && !u.user.hidden }) {
                    try await changeActiveUserAsync_(newActive.user.userId, viewPwd: nil)
                    try await deleteUser()
                }
            } else {
                try await deleteUser()
            }
        } catch let error {
            let a = getErrorAlert(error, "Error deleting user profile")
            alert = .error(title: a.title, error: a.message)
        }

        func deleteUser() async throws {
            try await apiDeleteUser(user.userId, delSMPQueues, viewPwd: viewPwd)
            await MainActor.run { withAnimation { m.removeUser(user) } }
        }
    }

    private func userView(_ user: User) -> some View {
        Button {
            Task {
                do {
                    try await changeActiveUserAsync_(user.userId, viewPwd: userViewPassword(user))
                } catch {
                    await MainActor.run { alert = .activateUserError(error: responseError(error)) }
                }
            }
        } label: {
            HStack {
                ProfileImage(imageStr: user.image, color: Color(uiColor: .tertiarySystemFill))
                    .frame(width: 44, height: 44)
                    .padding(.vertical, 4)
                    .padding(.trailing, 12)
                Text(user.chatViewName)
                Spacer()
                if user.activeUser {
                    Image(systemName: "checkmark").foregroundColor(.primary)
                } else if user.hidden {
                    Image(systemName: "lock").foregroundColor(.secondary)
                } else if !user.showNtfs {
                    Image(systemName: "speaker.slash").foregroundColor(.secondary)
                } else {
                    Image(systemName: "checkmark").foregroundColor(.clear)
                }
            }
        }
        .disabled(user.activeUser)
        .foregroundColor(.primary)
        .deleteDisabled(m.users.count <= 1)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if user.hidden {
                Button("Unhide") {
                    if passwordEntryRequired(user) {
                        profileAction = .unhideUser(user: user)
                    } else {
                        setUserPrivacy(user) { try await apiUnhideUser(user.userId, viewPwd: trimmedSearchTextOrPassword) }
                    }
                }
                .tint(.green)
            } else {
                if visibleUsersCount > 1 && prefPerformLA {
                    Button("Hide") {
                        selectedUser = user
                    }
                    .tint(.gray)
                }
                Group {
                    if user.showNtfs {
                        Button("Mute") {
                            setUserPrivacy(user, successAlert: showMuteProfileAlert ? .muteProfileAlert : nil) {
                                try await apiMuteUser(user.userId)
                            }
                        }
                    } else {
                        Button("Unmute") {
                            setUserPrivacy(user) { try await apiUnmuteUser(user.userId) }
                        }
                    }
                }
                .tint(.accentColor)
            }
        }
    }

    private func setUserPrivacy(_ user: User, successAlert: UserProfilesAlert? = nil, _ api: @escaping () async throws -> User) {
        Task {
            do {
                let u = try await api()
                await MainActor.run {
                    withAnimation { m.updateUser(u) }
                    if successAlert != nil {
                        alert = successAlert
                    }
                }
            } catch let error {
                let a = getErrorAlert(error, "Error updating user privacy")
                alert = .error(title: a.title, error: a.message)
            }
        }
    }
}

public func chatPasswordHash(_ pwd: String, _ salt: String) -> String {
    var cPwd = pwd.cString(using: .utf8)!
    var cSalt = salt.cString(using: .utf8)!
    let cHash  = chat_password_hash(&cPwd, &cSalt)!
    let hash = fromCString(cHash)
    return hash
}

struct UserProfilesView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfilesView()
    }
}
