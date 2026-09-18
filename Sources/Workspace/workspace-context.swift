import Foundation
import Path
import Position
import Readers

public struct WorkspaceContext: Sendable {
    let workspace: Workspace

    public let rootIdentifier: PathAccessRootIdentifier
    public let path: DescendantPath
    public let absoluteURL: URL

    init(
        workspace: Workspace,
        rootIdentifier: PathAccessRootIdentifier,
        path: DescendantPath,
        absoluteURL: URL
    ) {
        self.workspace = workspace
        self.rootIdentifier = rootIdentifier
        self.path = path
        self.absoluteURL = absoluteURL.standardizedFileURL
    }
}

public extension WorkspaceContext {
    func authorize(
        _ rawPath: String,
        capability: WorkspaceCapability,
        lineRange: LineRange? = nil,
        sourceSnapshot: FileReadSnapshot? = nil,
        at date: Date = Date()
    ) throws -> WorkspaceAuthorization {
        let baseURL = URL(
            fileURLWithPath: absoluteURL.path,
            isDirectory: true
        )
        let targetURL = URL(
            fileURLWithPath: rawPath,
            relativeTo: baseURL
        )
        .standardizedFileURL
        let targetPath = try workspace.paths.scope(
            targetURL,
            rootIdentifier: rootIdentifier
        )

        return try workspace.authorize(
            rootIdentifier: rootIdentifier,
            path: targetPath,
            capability: capability,
            lineRange: lineRange,
            sourceSnapshot: sourceSnapshot,
            at: date
        )
    }

    func requireCurrent(
        _ authorization: WorkspaceAuthorization,
        currentSourceSnapshot: FileReadSnapshot? = nil,
        at date: Date = Date()
    ) throws {
        try workspace.requireCurrent(
            authorization,
            currentSourceSnapshot: currentSourceSnapshot,
            at: date
        )
    }

    func reauthorize(
        _ authorization: WorkspaceAuthorization,
        currentSourceSnapshot: FileReadSnapshot? = nil,
        at date: Date = Date()
    ) throws -> WorkspaceAuthorization {
        try workspace.reauthorize(
            authorization,
            currentSourceSnapshot: currentSourceSnapshot,
            at: date
        )
    }
}

public extension Workspace {
    func context(
        at rawPath: String = ".",
        rootIdentifier: PathAccessRootIdentifier? = nil
    ) throws -> WorkspaceContext {
        let authorized = try paths.authorize(
            rawPath,
            rootIdentifier: rootIdentifier,
            type: .directory
        )

        return WorkspaceContext(
            workspace: self,
            rootIdentifier: authorized.rootIdentifier,
            path: authorized.path,
            absoluteURL: authorized.absoluteURL
        )
    }

    func context(
        at path: DescendantPath,
        rootIdentifier: PathAccessRootIdentifier? = nil
    ) throws -> WorkspaceContext {
        let authorized = try paths.authorize(
            path,
            rootIdentifier: rootIdentifier,
            type: .directory
        )

        return WorkspaceContext(
            workspace: self,
            rootIdentifier: authorized.rootIdentifier,
            path: authorized.path,
            absoluteURL: authorized.absoluteURL
        )
    }
}
