import Path
import Position
import Readers

public struct WorkspaceAuthorization:
    Sendable,
    Codable,
    Hashable
{
    public let authorizedPath: AuthorizedPath
    public let capability: WorkspaceCapability
    public let lineRange: LineRange?

    let sourceSnapshot: FileReadSnapshot?
    let grantIdentifier: WorkspaceGrantIdentifier
    let revision: WorkspaceRevision

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
