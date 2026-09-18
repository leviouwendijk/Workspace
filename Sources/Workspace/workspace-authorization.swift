import Path
import Position

public struct WorkspaceAuthorizationRequest:
    Sendable,
    Codable,
    Hashable
{
    public let rootIdentifier: PathAccessRootIdentifier?
    public let path: String
    public let capability: WorkspaceCapability
    public let lineRange: LineRange?

    public init(
        rootIdentifier: PathAccessRootIdentifier? = nil,
        path: String,
        capability: WorkspaceCapability,
        lineRange: LineRange? = nil
    ) {
        self.rootIdentifier = rootIdentifier
        self.path = path
        self.capability = capability
        self.lineRange = lineRange
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
    public let grantIdentifier: WorkspaceGrantIdentifier
    public let revision: WorkspaceRevision

    init(
        authorizedPath: AuthorizedPath,
        capability: WorkspaceCapability,
        lineRange: LineRange?,
        grantIdentifier: WorkspaceGrantIdentifier,
        revision: WorkspaceRevision
    ) {
        self.authorizedPath = authorizedPath
        self.capability = capability
        self.lineRange = lineRange
        self.grantIdentifier = grantIdentifier
        self.revision = revision
    }
}
