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
    case empty_installation
    case dynamic_content_scope
    case content_scope_requires_source_snapshot
    case source_snapshot_without_content
    case directory_content_scope
    case content_scope_requires_file_terminal
    case content_scope_requires_concrete_path
    case source_snapshot_missing_file
    case source_snapshot_path_mismatch(
        grant: WorkspaceGrantIdentifier
    )
    case invalid_content_capabilities(
        grant: WorkspaceGrantIdentifier,
        capabilities: [WorkspaceCapability]
    )
    case invalid_line_range_capability(WorkspaceCapability)
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
    case root_has_active_registrations(
        root: PathAccessRootIdentifier,
        registrations: [WorkspaceRegistrationIdentifier]
    )
    case registration_not_found(WorkspaceRegistrationIdentifier)
    case registration_not_active(WorkspaceRegistrationIdentifier)
    case authorization_denied(
        root: PathAccessRootIdentifier,
        path: String,
        capability: WorkspaceCapability
    )
    case source_snapshot_required(String)
    case stale_source_snapshot(String)
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

        case .empty_installation:
            return "Workspace installation must install at least one root or grant."

        case .dynamic_content_scope:
            return "Workspace authority cannot retain an unresolved dynamic content anchor."

        case .content_scope_requires_source_snapshot:
            return "Content-scoped workspace authority must be resolved against source snapshot evidence."

        case .source_snapshot_without_content:
            return "Source snapshot evidence may only be attached to a content-scoped selection."

        case .directory_content_scope:
            return "Directory selections cannot carry content-range authority."

        case .content_scope_requires_file_terminal:
            return "Content-scoped workspace authority must explicitly target a file."

        case .content_scope_requires_concrete_path:
            return "Content-scoped workspace authority must target one concrete path without wildcard components."

        case .source_snapshot_missing_file:
            return "Content-scoped workspace authority requires a snapshot of an existing file."

        case .source_snapshot_path_mismatch(let grant):
            return "Workspace grant '\(grant)' carries source snapshot evidence that does not resolve to its selected path."

        case .invalid_content_capabilities(let grant, let capabilities):
            let values = capabilities
                .map(\.rawValue)
                .joined(separator: ", ")
            return "Workspace grant '\(grant)' uses capabilities that cannot be content-range scoped: \(values)."

        case .invalid_line_range_capability(let capability):
            return "Workspace capability '\(capability.rawValue)' cannot be authorized over a line range."

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

        case .root_has_active_registrations(let root, let registrations):
            let values = registrations
                .map(\.description)
                .joined(separator: ", ")
            return "Workspace root '\(root.rawValue)' still belongs to active registrations: \(values)."

        case .registration_not_found(let identifier):
            return "Workspace registration '\(identifier)' is not installed."

        case .registration_not_active(let identifier):
            return "Workspace registration '\(identifier)' is no longer active."

        case .authorization_denied(let root, let path, let capability):
            return "Workspace capability '\(capability.rawValue)' is not granted for '\(path)' under root '\(root.rawValue)'."

        case .source_snapshot_required(let path):
            return "Workspace authorization for '\(path)' requires current source snapshot evidence."

        case .stale_source_snapshot(let path):
            return "Workspace authorization for '\(path)' was resolved against a different source snapshot."

        case .stale_authorization(let authorized, let current):
            return "Workspace authorization was issued at revision \(authorized.rawValue), but the current workspace revision is \(current.rawValue)."

        case .revision_overflow:
            return "Workspace revision counter overflowed."
        }
    }
}
