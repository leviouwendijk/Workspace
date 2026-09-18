import Path

public struct WorkspaceRegistration:
    Sendable,
    Codable,
    Hashable
{
    public let roots: [PathAccessRootIdentifier]
    public let grants: [WorkspaceGrantIdentifier]
    public let revision: WorkspaceRevision

    init(
        roots: [PathAccessRootIdentifier],
        grants: [WorkspaceGrantIdentifier],
        revision: WorkspaceRevision
    ) {
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

    public var isEmpty: Bool {
        roots.isEmpty && grants.isEmpty
    }
}

enum WorkspaceUpdateOperation {
    case install_root(PathAccessRoot)
    case install_grant(WorkspaceGrant)
    case replace_grant(WorkspaceGrant)
    case invalidate_grant(WorkspaceGrantIdentifier)
    case remove_root(PathAccessRootIdentifier)
}

public struct WorkspaceUpdate {
    var operations: [WorkspaceUpdateOperation] = []

    public init() {}

    public mutating func install(
        _ root: PathAccessRoot
    ) {
        operations.append(
            .install_root(
                root
            )
        )
    }

    public mutating func install(
        _ grant: WorkspaceGrant
    ) {
        operations.append(
            .install_grant(
                grant
            )
        )
    }

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
