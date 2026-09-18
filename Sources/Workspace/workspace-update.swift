import Foundation
import Path

public struct WorkspaceRegistration:
    Sendable,
    Codable,
    Hashable
{
    let rawValue: UUID

    init(
        rawValue: UUID = UUID()
    ) {
        self.rawValue = rawValue
    }
}

enum WorkspaceRegistrationState:
    Sendable,
    Codable,
    Hashable
{
    case active
    case invalidated(WorkspaceRevision)
}

struct WorkspaceRegistrationRecord:
    Sendable,
    Codable,
    Hashable
{
    let registration: WorkspaceRegistration
    let roots: [PathAccessRootIdentifier]
    let grants: [WorkspaceGrantIdentifier]
    let revision: WorkspaceRevision
    let state: WorkspaceRegistrationState

    init(
        registration: WorkspaceRegistration,
        roots: [PathAccessRootIdentifier],
        grants: [WorkspaceGrantIdentifier],
        revision: WorkspaceRevision,
        state: WorkspaceRegistrationState
    ) {
        self.registration = registration
        self.roots = Array(Set(roots)).sorted {
            $0.rawValue < $1.rawValue
        }
        self.grants = Array(Set(grants)).sorted {
            $0.rawValue < $1.rawValue
        }
        self.revision = revision
        self.state = state
    }
}

enum WorkspaceInstallationOperation {
    case root(PathAccessRoot)
    case grant(WorkspaceGrant)
}

public struct WorkspaceInstallation {
    var operations: [WorkspaceInstallationOperation] = []

    init() {}

    public mutating func install(
        _ root: PathAccessRoot
    ) {
        operations.append(.root(root))
    }

    public mutating func install(
        _ grant: WorkspaceGrant
    ) {
        operations.append(.grant(grant))
    }
}

enum WorkspaceUpdateOperation {
    case replace_grant(WorkspaceGrant)
    case invalidate_grant(WorkspaceGrantIdentifier)
}

struct WorkspaceUpdate {
    var operations: [WorkspaceUpdateOperation] = []

    mutating func replace(
        _ grant: WorkspaceGrant
    ) {
        operations.append(.replace_grant(grant))
    }

    mutating func invalidate(
        _ identifier: WorkspaceGrantIdentifier
    ) {
        operations.append(.invalidate_grant(identifier))
    }
}
