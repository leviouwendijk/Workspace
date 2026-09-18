import Foundation
import Path

public enum WorkspaceError:
    Error,
    Sendable,
    Hashable,
    LocalizedError
{
    case empty_grant_identifier
    case empty_capabilities(WorkspaceGrantIdentifier)
    case dynamic_content_scope
    case duplicate_root(PathAccessRootIdentifier)
    case root_not_found(PathAccessRootIdentifier)
    case duplicate_grant(WorkspaceGrantIdentifier)
    case grant_not_found(WorkspaceGrantIdentifier)
    case grant_identifier_mismatch
    case grant_root_not_installed(
        grant: WorkspaceGrantIdentifier,
        root: PathAccessRootIdentifier
    )
    case root_has_active_grants(
        root: PathAccessRootIdentifier,
        grants: [WorkspaceGrantIdentifier]
    )
    case authorization_denied(
        root: PathAccessRootIdentifier,
        path: String,
        capability: WorkspaceCapability
    )
    case stale_authorization(
        authorized: WorkspaceRevision,
        current: WorkspaceRevision
    )
    case revision_overflow

    public var errorDescription: String? {
        switch self {
        case .empty_grant_identifier:
            return "Workspace grant identifier cannot be empty."

        case .empty_capabilities(let identifier):
            return "Workspace grant '\(identifier)' must contain at least one capability."

        case .dynamic_content_scope:
            return "Workspace authority cannot retain an unresolved dynamic content anchor. Resolve the selection before granting authority."

        case .duplicate_root(let identifier):
            return "Workspace root '\(identifier.rawValue)' is already installed."

        case .root_not_found(let identifier):
            return "Workspace root '\(identifier.rawValue)' is not installed."

        case .duplicate_grant(let identifier):
            return "Workspace grant '\(identifier)' is already installed."

        case .grant_not_found(let identifier):
            return "Workspace grant '\(identifier)' is not installed."

        case .grant_identifier_mismatch:
            return "Workspace grant storage key does not match its grant identifier."

        case .grant_root_not_installed(let grant, let root):
            return "Workspace grant '\(grant)' refers to root '\(root.rawValue)', which is not installed."

        case .root_has_active_grants(let root, let grants):
            let values = grants
                .map(\.rawValue)
                .joined(separator: ", ")
            return "Workspace root '\(root.rawValue)' still has active grants: \(values)."

        case .authorization_denied(let root, let path, let capability):
            return "Workspace capability '\(capability.rawValue)' is not granted for '\(path)' under root '\(root.rawValue)'."

        case .stale_authorization(let authorized, let current):
            return "Workspace authorization was issued at revision \(authorized.rawValue), but the current workspace revision is \(current.rawValue)."

        case .revision_overflow:
            return "Workspace revision counter overflowed."
        }
    }
}
