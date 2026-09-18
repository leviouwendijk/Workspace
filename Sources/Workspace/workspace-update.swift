import Foundation
import Path

public struct WorkspaceRegistrationIdentifier:
    Sendable,
    Codable,
    Hashable,
    CustomStringConvertible
{
    public let rawValue: UUID

    public init(
        rawValue: UUID = UUID()
    ) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue.uuidString
    }
}

public struct WorkspaceRegistration:
    Sendable,
    Codable,
    Hashable,
    Identifiable
{
    public let id: WorkspaceRegistrationIdentifier
    public let roots: [PathAccessRootIdentifier]
    public let grants: [WorkspaceGrantIdentifier]
    public let revision: WorkspaceRevision

    init(
        id: WorkspaceRegistrationIdentifier,
        roots: [PathAccessRootIdentifier],
        grants: [WorkspaceGrantIdentifier],
        revision: WorkspaceRevision
    ) {
        self.id = id
        self.roots = Array(
            Set(roots)
        )
        .sorted {
            $0.rawValue < $1.rawValue
        }
        self.grants = Array(
            Set(grants)
        )
        .sorted {
            $0.rawValue < $1.rawValue
        }
        self.revision = revision
    }
}

public enum WorkspaceRegistrationState:
    Sendable,
    Codable,
    Hashable
{
    case active
    case invalidated(WorkspaceRevision)
}

public struct WorkspaceRegistrationRecord:
    Sendable,
    Codable,
    Hashable
{
    public let registration: WorkspaceRegistration
    public let state: WorkspaceRegistrationState

    init(
        registration: WorkspaceRegistration,
        state: WorkspaceRegistrationState
    ) {
        self.registration = registration
        self.state = state
    }
}

enum WorkspaceInstallationOperation {
    case root(PathAccessRoot)
    case grant(WorkspaceGrant)
}

public struct WorkspaceInstallation {
    var operations: [WorkspaceInstallationOperation] = []

    public init() {}

    public mutating func install(
        _ root: PathAccessRoot
    ) {
        operations.append(
            .root(
                root
            )
        )
    }

    public mutating func install(
        _ grant: WorkspaceGrant
    ) {
        operations.append(
            .grant(
                grant
            )
        )
    }
}

enum WorkspaceUpdateOperation {
    case replace_grant(WorkspaceGrant)
    case invalidate_grant(WorkspaceGrantIdentifier)
    case remove_root(PathAccessRootIdentifier)
}

public struct WorkspaceUpdate {
    var operations: [WorkspaceUpdateOperation] = []

    public init() {}

    public mutating func replace(
        _ grant: WorkspaceGrant
    ) {
        operations.append(
            .replace_grant(
                grant
            )
        )
    }

    public mutating func invalidate(
        _ identifier: WorkspaceGrantIdentifier
    ) {
        operations.append(
            .invalidate_grant(
                identifier
            )
        )
    }

    public mutating func removeRoot(
        _ identifier: PathAccessRootIdentifier
    ) {
        operations.append(
            .remove_root(
                identifier
            )
        )
    }
}
