import Foundation
import Path
import Position
import Readers

public struct WorkspaceContext: Sendable {
    public enum Targeting:
        Sendable,
        Codable,
        Hashable
    {
        case fixed
        case root
    }

    let workspace: Workspace

    public let rootIdentifier: PathAccessRootIdentifier
    public let rootURL: URL
    public let path: DescendantPath
    public let absoluteURL: URL
    public let targeting: Targeting
    public let execution: WorkspaceExecution

    init(
        workspace: Workspace,
        rootIdentifier: PathAccessRootIdentifier,
        rootURL: URL,
        path: DescendantPath,
        absoluteURL: URL,
        targeting: Targeting,
        execution: WorkspaceExecution
    ) {
        self.workspace = workspace
        self.rootIdentifier = rootIdentifier
        self.rootURL = rootURL.standardizedFileURL
        self.path = path
        self.absoluteURL = absoluteURL.standardizedFileURL
        self.targeting = targeting
        self.execution = execution
    }
}

public extension WorkspaceContext {
    var revision: WorkspaceRevision {
        workspace.revision
    }

    var roots: [PathAccessRoot] {
        workspace.roots
    }

    var defaultRootIdentifier: PathAccessRootIdentifier? {
        workspace.defaultRootIdentifier
    }

    var grants: [WorkspaceGrant] {
        workspace.grants
    }

    func grant(
        identifier: WorkspaceGrantIdentifier
    ) -> WorkspaceGrant? {
        workspace.grant(
            identifier: identifier
        )
    }

    func status(
        of identifier: WorkspaceGrantIdentifier,
        at date: Date = Date()
    ) -> WorkspaceGrantStatus? {
        workspace.status(
            of: identifier,
            at: date
        )
    }

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
        // A path outside this context's root goes through the innermost
        // root that contains it, under that root's grants and policy.
        let root = Self.contains(rootURL, targetURL)
            ? rootIdentifier
            : containingRoot(of: targetURL) ?? rootIdentifier
        let targetPath = try workspace.paths.scope(
            targetURL,
            rootIdentifier: root
        )

        let authorization = try workspace.authorize(
            rootIdentifier: root,
            path: targetPath,
            capability: capability,
            lineRange: lineRange,
            sourceSnapshot: sourceSnapshot,
            at: date
        )
        guard root != rootIdentifier else {
            return authorization
        }
        // Relative to another root, a presentation path would read as one
        // of this root's; the absolute path names it unambiguously.
        return authorization.presenting(
            authorization.authorizedPath.absoluteURL.path
        )
    }

    /// The innermost other root containing `url`, if any.
    func containingRoot(
        of url: URL
    ) -> PathAccessRootIdentifier? {
        roots
            .filter { Self.contains($0.scope.rootURL, url) }
            .max { $0.scope.rootURL.pathComponents.count < $1.scope.rootURL.pathComponents.count }?
            .id
    }

    static func contains(
        _ root: URL,
        _ url: URL
    ) -> Bool {
        let base = root.standardizedFileURL.pathComponents
        let path = url.standardizedFileURL.pathComponents
        return path.count >= base.count && Array(path.prefix(base.count)) == base
    }

    /// The same workspace and execution, targeted at another root's top.
    /// For an operation whose targets all lie in that root.
    func context(
        forRoot root: PathAccessRootIdentifier
    ) throws -> WorkspaceContext {
        try workspace.context(
            at: ".",
            rootIdentifier: root,
            targeting: targeting,
            execution: execution
        )
    }

    func context(
        atRootPath rawPath: String
    ) throws -> WorkspaceContext {
        guard targeting == .root else {
            throw WorkspaceError.retargeting_disabled
        }

        return try workspace.context(
            at: rawPath,
            rootIdentifier: rootIdentifier,
            targeting: targeting,
            execution: execution
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
        rootIdentifier: PathAccessRootIdentifier? = nil,
        targeting: WorkspaceContext.Targeting = .root,
        execution: WorkspaceExecution
    ) throws -> WorkspaceContext {
        let authorized = try paths.authorize(
            rawPath,
            rootIdentifier: rootIdentifier,
            type: .directory
        )

        let root = try paths.authorize(
            ".",
            rootIdentifier: authorized.rootIdentifier,
            type: .directory
        )

        return WorkspaceContext(
            workspace: self,
            rootIdentifier: authorized.rootIdentifier,
            rootURL: root.absoluteURL,
            path: authorized.path,
            absoluteURL: authorized.absoluteURL,
            targeting: targeting,
            execution: execution
        )
    }

    func context(
        at path: DescendantPath,
        rootIdentifier: PathAccessRootIdentifier? = nil,
        targeting: WorkspaceContext.Targeting = .root,
        execution: WorkspaceExecution
    ) throws -> WorkspaceContext {
        let authorized = try paths.authorize(
            path,
            rootIdentifier: rootIdentifier,
            type: .directory
        )

        let root = try paths.authorize(
            ".",
            rootIdentifier: authorized.rootIdentifier,
            type: .directory
        )

        return WorkspaceContext(
            workspace: self,
            rootIdentifier: authorized.rootIdentifier,
            rootURL: root.absoluteURL,
            path: authorized.path,
            absoluteURL: authorized.absoluteURL,
            targeting: targeting,
            execution: execution
        )
    }
}
