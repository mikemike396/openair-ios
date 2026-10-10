import SwiftUI

extension EnvironmentValues {
    @Entry var appCoordinator: AppCoordinator? = nil
}

/// Checks injection when a view consumes the coordinator, not while SwiftUI writes the environment.
@propertyWrapper
struct AppCoordinatorEnvironment: DynamicProperty {
    @Environment(\.appCoordinator) private var coordinator

    var wrappedValue: AppCoordinator {
        guard let coordinator else {
            preconditionFailure("Inject AppCoordinator using withDependencies before presenting app views.")
        }
        return coordinator
    }
}
