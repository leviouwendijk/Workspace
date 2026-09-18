import Path
import Position
import Readers

public struct WorkspaceAuthorizationRequest:
    Sendable,
    Codable,
    Hashable
{
    public let rootIdentifier: PathAccessRootIdentifier?
    public let path: String
    public let capability: WorkspaceCapability
    public let lineRange: LineRange?
    public let sourceSnapshot: FileReadSnapshot?

    public init(
        rootIdentifier: PathAccessRootIdentifier? = nil,
        path: String,
        capability: WorkspaceCapability,
        lineRange: LineRange? = nil,
        sourceSnapshot: FileReadSnapshot? = nil
    ) throws {
        if lineRange != nil,
           !capability.supportsContentRange
        {
            throw WorkspaceError.invalid_line_range_capability(
                capability
            )
        }

        self.rootIdentifier = rootIdentifier
        self.path = path
        self.capability = capability
        self.lineRange = lineRange
        self.sourceSnapshot = sourceSnapshot
    }
}

public struct WorkspaceAuthorization:
    Sendable,
    Codable,
    Hashable
{
    public let authorizedPath: AuthorizedPath
    public let capability: WorkspaceCapability
    public let lineRange: LineRange?
    public let sourceSnapshot: FileReadSnapshot?
    public let grantIdentifier: WorkspaceGrantIdentifier
    public let revision: WorkspaceRevision

    init(
        authorizedPath: AuthorizedPath,
        capability: WorkspaceCapability,
        lineRange: LineRange?,
        sourceSnapshot: FileReadSnapshot?,
        grantIdentifier: WorkspaceGrantIdentifier,
        revision: WorkspaceRevision
    ) {
        self.authorizedPath = authorizedPath
        self.capability = capability
        self.lineRange = lineRange
        self.sourceSnapshot = sourceSnapshot
        self.grantIdentifier = grantIdentifier
        self.revision = revision
    }
}
