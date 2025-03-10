//
//  SettingsView.swift
//  SimpleX
//
//  Created by Evgeny Poberezkin on 31/01/2022.
//  Copyright © 2022 SimpleX Chat. All rights reserved.
//

import SwiftUI
import StoreKit
import SimpleXChat

let simplexTeamURL = URL(string: "simplex:/contact#/?v=1&smp=smp%3A%2F%2FPQUV2eL0t7OStZOoAsPEV2QYWt4-xilbakvGUGOItUo%3D%40smp6.simplex.im%2FK1rslx-m5bpXVIdMZg9NLUZ_8JBm8xTt%23MCowBQYDK2VuAyEALDeVe-sG8mRY22LsXlPgiwTNs9dbiLrNuA7f3ZMAJ2w%3D")!

let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")  as? String

let DEFAULT_SHOW_LA_NOTICE = "showLocalAuthenticationNotice"
let DEFAULT_LA_NOTICE_SHOWN = "localAuthenticationNoticeShown"
let DEFAULT_PERFORM_LA = "performLocalAuthentication"
let DEFAULT_NOTIFICATION_ALERT_SHOWN = "notificationAlertShown"
let DEFAULT_WEBRTC_POLICY_RELAY = "webrtcPolicyRelay"
let DEFAULT_WEBRTC_ICE_SERVERS = "webrtcICEServers"
let DEFAULT_CALL_KIT_CALLS_IN_RECENTS = "callKitCallsInRecents"
let DEFAULT_PRIVACY_ACCEPT_IMAGES = "privacyAcceptImages"
let DEFAULT_PRIVACY_LINK_PREVIEWS = "privacyLinkPreviews"
let DEFAULT_PRIVACY_SIMPLEX_LINK_MODE = "privacySimplexLinkMode"
let DEFAULT_PRIVACY_PROTECT_SCREEN = "privacyProtectScreen"
let DEFAULT_EXPERIMENTAL_CALLS = "experimentalCalls"
let DEFAULT_CHAT_ARCHIVE_NAME = "chatArchiveName"
let DEFAULT_CHAT_ARCHIVE_TIME = "chatArchiveTime"
let DEFAULT_CHAT_V3_DB_MIGRATION = "chatV3DBMigration"
let DEFAULT_DEVELOPER_TOOLS = "developerTools"
let DEFAULT_ENCRYPTION_STARTED = "encryptionStarted"
let DEFAULT_ENCRYPTION_STARTED_AT = "encryptionStartedAt"
let DEFAULT_ACCENT_COLOR_RED = "accentColorRed"
let DEFAULT_ACCENT_COLOR_GREEN = "accentColorGreen"
let DEFAULT_ACCENT_COLOR_BLUE = "accentColorBlue"
let DEFAULT_USER_INTERFACE_STYLE = "userInterfaceStyle"
let DEFAULT_CONNECT_VIA_LINK_TAB = "connectViaLinkTab"
let DEFAULT_LIVE_MESSAGE_ALERT_SHOWN = "liveMessageAlertShown"
let DEFAULT_SHOW_HIDDEN_PROFILES_NOTICE = "showHiddenProfilesNotice"
let DEFAULT_SHOW_MUTE_PROFILE_ALERT = "showMuteProfileAlert"
let DEFAULT_WHATS_NEW_VERSION = "defaultWhatsNewVersion"

let appDefaults: [String: Any] = [
    DEFAULT_SHOW_LA_NOTICE: false,
    DEFAULT_LA_NOTICE_SHOWN: false,
    DEFAULT_PERFORM_LA: false,
    DEFAULT_NOTIFICATION_ALERT_SHOWN: false,
    DEFAULT_WEBRTC_POLICY_RELAY: true,
    DEFAULT_CALL_KIT_CALLS_IN_RECENTS: false,
    DEFAULT_PRIVACY_ACCEPT_IMAGES: true,
    DEFAULT_PRIVACY_LINK_PREVIEWS: true,
    DEFAULT_PRIVACY_SIMPLEX_LINK_MODE: "description",
    DEFAULT_PRIVACY_PROTECT_SCREEN: false,
    DEFAULT_EXPERIMENTAL_CALLS: false,
    DEFAULT_CHAT_V3_DB_MIGRATION: "offer",
    DEFAULT_DEVELOPER_TOOLS: false,
    DEFAULT_ENCRYPTION_STARTED: false,
    DEFAULT_ACCENT_COLOR_RED: 0.000,
    DEFAULT_ACCENT_COLOR_GREEN: 0.533,
    DEFAULT_ACCENT_COLOR_BLUE: 1.000,
    DEFAULT_USER_INTERFACE_STYLE: 0,
    DEFAULT_CONNECT_VIA_LINK_TAB: "scan",
    DEFAULT_LIVE_MESSAGE_ALERT_SHOWN: false,
    DEFAULT_SHOW_HIDDEN_PROFILES_NOTICE: true,
    DEFAULT_SHOW_MUTE_PROFILE_ALERT: true,
]

enum SimpleXLinkMode: String, Identifiable {
    case description
    case full
    case browser

    static var values: [SimpleXLinkMode] = [.description, .full, .browser]

    public var id: Self { self }

    var text: LocalizedStringKey {
        switch self {
        case .description: return "Description"
        case .full: return "Full link"
        case .browser: return "Via browser"
        }
    }
}

private var indent: CGFloat = 36

let chatArchiveTimeDefault = DateDefault(defaults: UserDefaults.standard, forKey: DEFAULT_CHAT_ARCHIVE_TIME)

let encryptionStartedDefault = BoolDefault(defaults: UserDefaults.standard, forKey: DEFAULT_ENCRYPTION_STARTED)

let encryptionStartedAtDefault = DateDefault(defaults: UserDefaults.standard, forKey: DEFAULT_ENCRYPTION_STARTED_AT)

let connectViaLinkTabDefault = EnumDefault<ConnectViaLinkTab>(defaults: UserDefaults.standard, forKey: DEFAULT_CONNECT_VIA_LINK_TAB, withDefault: .scan)

let privacySimplexLinkModeDefault = EnumDefault<SimpleXLinkMode>(defaults: UserDefaults.standard, forKey: DEFAULT_PRIVACY_SIMPLEX_LINK_MODE, withDefault: .description)

func setGroupDefaults() {
    privacyAcceptImagesGroupDefault.set(UserDefaults.standard.bool(forKey: DEFAULT_PRIVACY_ACCEPT_IMAGES))
}

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var sceneDelegate: SceneDelegate
    @Binding var showSettings: Bool
    @State private var settingsSheet: SettingsSheet?

    var body: some View {
        let user: User = chatModel.currentUser!

        NavigationView {
            List {
                Section("You") {
                    NavigationLink {
                        UserProfile()
                            .navigationTitle("Your current profile")
                    } label: {
                        ProfilePreview(profileOf: user)
                        .padding(.leading, -8)
                    }

                    NavigationLink {
                        UserProfilesView()
                    } label: {
                        settingsRow("person.crop.rectangle.stack") { Text("Your chat profiles") }
                    }

                    incognitoRow()

                    NavigationLink {
                        CreateLinkView(selection: .longTerm, viaNavLink: true)
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        settingsRow("qrcode") { Text("Your SimpleX contact address") }
                    }

                    NavigationLink {
                        PreferencesView(profile: user.profile, preferences: user.fullPreferences, currentPreferences: user.fullPreferences)
                            .navigationTitle("Your preferences")
                    } label: {
                        settingsRow("switch.2") { Text("Chat preferences") }
                    }
                }
                .disabled(chatModel.chatRunning != true)
                
                Section("Settings") {
                    NavigationLink {
                        NotificationsView()
                            .navigationTitle("Notifications")
                    } label: {
                        HStack {
                            notificationsIcon()
                            Text("Notifications")
                        }
                    }
                    .disabled(chatModel.chatRunning != true)
                    
                    NavigationLink {
                        NetworkAndServers()
                            .navigationTitle("Network & servers")
                    } label: {
                        settingsRow("externaldrive.connected.to.line.below") { Text("Network & servers") }
                    }
                    .disabled(chatModel.chatRunning != true)
                    
                    NavigationLink {
                        CallSettings()
                            .navigationTitle("Your calls")
                    } label: {
                        settingsRow("video") { Text("Audio & video calls") }
                    }
                    .disabled(chatModel.chatRunning != true)
                    
                    NavigationLink {
                        PrivacySettings()
                            .navigationTitle("Your privacy")
                    } label: {
                        settingsRow("lock") { Text("Privacy & security") }
                    }
                    .disabled(chatModel.chatRunning != true)
                    
                    if UIApplication.shared.supportsAlternateIcons {
                        NavigationLink {
                            AppearanceSettings()
                                .navigationTitle("Appearance")
                        } label: {
                            settingsRow("sun.max") { Text("Appearance") }
                        }
                        .disabled(chatModel.chatRunning != true)
                    }
                    
                    chatDatabaseRow()
                }

                Section("Help") {
                    NavigationLink {
                        ChatHelp(showSettings: $showSettings)
                            .navigationTitle("Welcome \(user.displayName)!")
                            .frame(maxHeight: .infinity, alignment: .top)
                    } label: {
                        settingsRow("questionmark") { Text("How to use it") }
                    }
                    NavigationLink {
                        WhatsNewView(viaSettings: true)
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        settingsRow("plus") { Text("What's new") }
                    }
                    NavigationLink {
                        SimpleXInfo(onboarding: false)
                            .navigationBarTitle("", displayMode: .inline)
                            .frame(maxHeight: .infinity, alignment: .top)
                    } label: {
                        settingsRow("info") { Text("About SimpleX Chat") }
                    }
//                    NavigationLink {
//                        MarkdownHelp()
//                            .padding()
//                            .navigationTitle("How to use markdown")
//                            .frame(maxHeight: .infinity, alignment: .top)
//                    } label: {
//                        settingsRow("textformat") { Text("Markdown in messages") }
//                    }
                    settingsRow("number") {
                        Button("Send questions and ideas") {
                            showSettings = false
                            DispatchQueue.main.async {
                                UIApplication.shared.open(simplexTeamURL)
                            }
                        }
                    }
                    .disabled(chatModel.chatRunning != true)
                    settingsRow("envelope") { Text("[Send us email](mailto:chat@simplex.chat)") }
                }

                Section("Support SimpleX Chat") {
                    settingsRow("keyboard") { Text("[Contribute](https://github.com/simplex-chat/simplex-chat#contribute)") }
                    settingsRow("star") {
                        Button("Rate the app") {
                            if let scene = sceneDelegate.windowScene {
                                SKStoreReviewController.requestReview(in: scene)
                            }
                        }
                    }
                    ZStack(alignment: .leading) {
                        Image(colorScheme == .dark ? "github_light" : "github")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .opacity(0.5)
                        Text("[Star on GitHub](https://github.com/simplex-chat/simplex-chat)")
                            .padding(.leading, indent)
                    }
                }

                Section("Develop") {
                    NavigationLink {
                        DeveloperView()
                            .navigationTitle("Developer tools")
                    } label: {
                        settingsRow("chevron.left.forwardslash.chevron.right") { Text("Developer tools") }
                    }
//                    NavigationLink {
//                        ExperimentalFeaturesView()
//                            .navigationTitle("Experimental features")
//                    } label: {
//                        settingsRow("gauge") { Text("Experimental features") }
//                    }
                    NavigationLink {
                        VersionView()
                            .navigationBarTitle("App version")
                    } label: {
                        Text("v\(appVersion ?? "?") (\(appBuild ?? "?"))")
                    }
                }
            }
            .navigationTitle("Your settings")
        }
        .sheet(item: $settingsSheet) { sheet in
            switch sheet {
            case .incognitoInfo: IncognitoHelp()
            }
        }
    }

    @ViewBuilder private func incognitoRow() -> some View {
        ZStack(alignment: .leading) {
            Image(systemName: chatModel.incognito ? "theatermasks.fill" : "theatermasks")
                .frame(maxWidth: 24, maxHeight: 24, alignment: .center)
                .foregroundColor(chatModel.incognito ? Color.indigo : .secondary)
            Toggle(isOn: $chatModel.incognito) {
                HStack {
                    Text("Incognito")
                    Spacer().frame(width: 4)
                    Image(systemName: "info.circle")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 14))
                }
                .onTapGesture {
                    settingsSheet = .incognitoInfo
                }
            }
            .onChange(of: chatModel.incognito) { incognito in
                incognitoGroupDefault.set(incognito)
                do {
                    try apiSetIncognito(incognito: incognito)
                } catch {
                    logger.error("apiSetIncognito: cannot set incognito \(responseError(error))")
                }
            }
            .padding(.leading, indent)
        }
    }
    
    private func chatDatabaseRow() -> some View {
        NavigationLink {
            DatabaseView(showSettings: $showSettings, chatItemTTL: chatModel.chatItemTTL)
                .navigationTitle("Your chat database")
        } label: {
            let color: Color = chatModel.chatDbEncrypted == false ? .orange : .secondary
            settingsRow("internaldrive", color: color) {
                HStack {
                    Text("Database passphrase & export")
                    Spacer()
                    if chatModel.chatRunning == false {
                        Image(systemName: "exclamationmark.octagon.fill").foregroundColor(.red)
                    }
                }
            }
        }
    }

    private enum SettingsSheet: Identifiable {
        case incognitoInfo

        var id: SettingsSheet { get { self } }
    }

    private enum NotificationAlert {
        case enable
        case error(LocalizedStringKey, String)
    }

    private func notificationsIcon() -> some View {
        let icon: String
        let color: Color
        switch (chatModel.tokenStatus) {
        case .new:
            icon = "bolt"
            color = .secondary
        case .registered:
            icon = "bolt.fill"
            color = .secondary
        case .invalid:
            icon = "bolt.slash"
            color = .secondary
        case .confirmed:
            icon = "bolt.fill"
            color = .yellow
        case .active:
            icon = "bolt.fill"
            color = .green
        case .expired:
            icon = "bolt.slash.fill"
            color = .secondary
        case .none:
            icon = "bolt"
            color = .secondary
        }
        return Image(systemName: icon)
            .padding(.trailing, 9)
            .foregroundColor(color)
    }
}

func settingsRow<Content : View>(_ icon: String, color: Color = .secondary, content: @escaping () -> Content) -> some View {
    ZStack(alignment: .leading) {
        Image(systemName: icon).frame(maxWidth: 24, maxHeight: 24, alignment: .center).foregroundColor(color)
        content().padding(.leading, indent)
    }
}

struct ProfilePreview: View {
    var profileOf: NamedChat
    var color = Color(uiColor: .tertiarySystemFill)

    var body: some View {
        HStack {
            ProfileImage(imageStr: profileOf.image, color: color)
                .frame(width: 44, height: 44)
                .padding(.trailing, 6)
                .padding(.vertical, 6)
            VStack(alignment: .leading) {
                Text(profileOf.displayName)
                    .fontWeight(.bold)
                    .font(.title2)
                Text(profileOf.fullName)
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let chatModel = ChatModel()
        chatModel.currentUser = User.sampleData
        @State var showSettings = false

        return SettingsView(showSettings: $showSettings)
            .environmentObject(chatModel)
    }
}
