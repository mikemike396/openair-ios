import Foundation
import Observation

fileprivate extension String {
    static let onboarding = "hasCompletedOnboarding"
    static let place = "savedPlace"
    static let preferences = "comfortPreferences"
}

protocol UserPreferenceStoring {
    var hasCompletedOnboarding: Bool { get set }
    var savedPlace: SavedPlace? { get set }
    var preferences: ComfortPreferences { get set }
}

@Observable
final class UserPreferenceStore: UserPreferenceStoring {
    private let userDefaults: UserDefaults
    private let defaultPreferences: ComfortPreferences

    init(
        userDefaults: UserDefaults = .standard,
        locale: Locale = .autoupdatingCurrent
    ) {
        self.userDefaults = userDefaults
        defaultPreferences = .default(for: locale)

        if userDefaults.data(forKey: .preferences) == nil {
            preferences = defaultPreferences
        }
    }

    var hasCompletedOnboarding: Bool {
        get {
            getter(
                keyPath: \.hasCompletedOnboarding,
                key: .onboarding,
                defaultValue: false
            )
        }
        set {
            setter(
                keyPath: \.hasCompletedOnboarding,
                key: .onboarding,
                newValue: newValue
            )
        }
    }

    var savedPlace: SavedPlace? {
        get {
            getter(
                keyPath: \.savedPlace,
                key: .place,
                defaultValue: nil
            )
        }
        set {
            setter(
                keyPath: \.savedPlace,
                key: .place,
                newValue: newValue
            )
        }
    }

    var preferences: ComfortPreferences {
        get {
            getter(
                keyPath: \.preferences,
                key: .preferences,
                defaultValue: defaultPreferences
            )
        }
        set {
            setter(
                keyPath: \.preferences,
                key: .preferences,
                newValue: newValue
            )
        }
    }

    /// Generic access method for reading values from UserDefaults
    /// - Parameter keyPath: KeyPath to the property in UserPreferenceStore
    /// - Parameter key: The UserDefaults key to access
    /// - Parameter defaultValue: The default value to return if the key is not found
    /// - Returns: The value of the property, or the default value if not found
    private func getter<T: Decodable>(
        keyPath: KeyPath<UserPreferenceStore, T>,
        key: String,
        defaultValue: T
    ) -> T {
        access(keyPath: keyPath)
        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(T.self, from: data)
        {
            return decoded
        } else {
            return defaultValue
        }
    }

    /// Generic access method for writing any Encodable value to UserDefaults
    /// - Parameter keyPath: KeyPath to the property in UserPreferenceStore
    /// - Parameter key: The UserDefaults key to store the value under
    /// - Parameter newValue: The value to encode and store in UserDefaults
    private func setter<T: Encodable>(
          keyPath: KeyPath<UserPreferenceStore, T>,
          key: String,
          newValue: T
      ) {
          withMutation(keyPath: keyPath) {
              if let data = try? JSONEncoder().encode(newValue) {
                  userDefaults.set(data, forKey: key)
              }
          }
      }
}
