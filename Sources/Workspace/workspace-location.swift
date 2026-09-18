import Foundation
import Path

public struct WorkspaceLocation:
    Sendable,
    Codable,
    Hashable
{
    public let path: DescendantPath
    public let absoluteURL: URL

    public init(
        path: DescendantPath,
        absoluteURL: URL
    ) {
        self.path = path
        self.absoluteURL = absoluteURL.standardizedFileURL
    }
}

public extension Workspace {
    var rootURL: URL? {
        guard let defaultRootIdentifier,
              let root = root(
                identifier: defaultRootIdentifier
              )
        else {
            return nil
        }

        return root.rootURL
    }

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
            path: authorized.path,
            absoluteURL: authorized.absoluteURL
        )
    }
}
