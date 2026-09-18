import Foundation
import Path

public struct WorkspaceLocation:
    Sendable,
    Codable,
    Hashable
{
    public let rootIdentifier: PathAccessRootIdentifier
    public let path: DescendantPath
    public let absoluteURL: URL

    init(
        rootIdentifier: PathAccessRootIdentifier,
        path: DescendantPath,
        absoluteURL: URL
    ) {
        self.rootIdentifier = rootIdentifier
        self.path = path
        self.absoluteURL = absoluteURL.standardizedFileURL
    }
}

public extension Workspace {
    func location(
        _ rawPath: String,
        rootIdentifier: PathAccessRootIdentifier? = nil
    ) throws -> WorkspaceLocation {
        let authorized = try paths.authorize(
            rawPath,
            rootIdentifier: rootIdentifier,
            type: .directory
        )

        return WorkspaceLocation(
            rootIdentifier: authorized.rootIdentifier,
            path: authorized.path,
            absoluteURL: authorized.absoluteURL
        )
    }

    func location(
        _ path: DescendantPath,
        rootIdentifier: PathAccessRootIdentifier? = nil
    ) throws -> WorkspaceLocation {
        let authorized = try paths.authorize(
            path,
            rootIdentifier: rootIdentifier,
            type: .directory
        )

        return WorkspaceLocation(
            rootIdentifier: authorized.rootIdentifier,
            path: authorized.path,
            absoluteURL: authorized.absoluteURL
        )
    }
}
