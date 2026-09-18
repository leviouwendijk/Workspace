import Foundation
import Path
import Position
import Readers
import Selection
import Workspace

enum RegressionFailure: Error {
    case assertion(String)
}

func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) throws {
    guard condition() else {
        throw RegressionFailure.assertion(
            message
        )
    }
}

func requireSnapshot(
    _ url: URL
) throws -> FileReadSnapshot {
    let result = try LineReader(
        url
    ).read()

    guard let snapshot = result.fileSnapshot else {
        throw RegressionFailure.assertion(
            "reader did not produce a source snapshot"
        )
    }

    return snapshot
}

func workspaceAuthorityHardening() throws {
    let fileManager = FileManager.default
    let fixtureRoot = fileManager.temporaryDirectory
        .appendingPathComponent(
            "workspace-hardening-\(UUID().uuidString)",
            isDirectory: true
        )
    let projectURL = fixtureRoot.appendingPathComponent(
        "project",
        isDirectory: true
    )
    let externalURL = fixtureRoot.appendingPathComponent(
        "external",
        isDirectory: true
    )

    try fileManager.createDirectory(
        at: projectURL,
        withIntermediateDirectories: true
    )
    try fileManager.createDirectory(
        at: externalURL,
        withIntermediateDirectories: true
    )

    defer {
        try? fileManager.removeItem(
            at: fixtureRoot
        )
    }

    let baseURL = projectURL.appendingPathComponent(
        "base.txt"
    )
    let boundedURL = projectURL.appendingPathComponent(
        "bounded.txt"
    )
    let externalFileURL = externalURL.appendingPathComponent(
        "external.txt"
    )

    try "base\n".write(
        to: baseURL,
        atomically: true,
        encoding: .utf8
    )
    try "one\ntwo\nthree\nfour\nfive\n".write(
        to: boundedURL,
        atomically: true,
        encoding: .utf8
    )
    try "external\n".write(
        to: externalFileURL,
        atomically: true,
        encoding: .utf8
    )

    let projectID = PathAccessRootIdentifier(
        rawValue: "project"
    )
    let externalID = PathAccessRootIdentifier(
        rawValue: "external"
    )
    let projectRoot = PathAccessRoot(
        id: projectID,
        label: "Project",
        scope: try PathAccessScope(
            root: projectURL,
            policy: .defaults.workspace
        ),
        isDefault: true
    )
    let projectGrant = try WorkspaceGrant(
        id: try WorkspaceGrantIdentifier(
            "project-read"
        ),
        rootIdentifier: projectID,
        capabilities: [
            .read,
        ]
    )

    var emptyWorkspaceRejected = false

    do {
        _ = try Workspace(
            roots: []
        )
    } catch WorkspaceError.empty_roots {
        emptyWorkspaceRejected = true
    }

    try expect(
        emptyWorkspaceRejected,
        "workspace construction rejects an authority graph without roots"
    )

    var workspace = try Workspace(
        root: projectRoot,
        grants: [
            projectGrant,
        ]
    )

    try expect(
        workspace.grants == [projectGrant],
        "workspace exposes semantic grants without exposing grant records"
    )
    try expect(
        workspace.grant(
            identifier: projectGrant.id
        ) == projectGrant,
        "workspace resolves a semantic grant by identifier"
    )

    let projectContext = try workspace.context(
        rootIdentifier: projectID
    )

    try expect(
        projectContext.rootIdentifier == projectID,
        "workspace context retains the root actually selected by Path authority"
    )
    try expect(
        projectContext.absoluteURL == projectURL.standardizedFileURL,
        "workspace context exposes the resolved execution anchor"
    )
    try expect(
        projectContext.revision == workspace.revision,
        "workspace context exposes the authority revision of its invocation snapshot"
    )
    try expect(
        projectContext.roots == workspace.roots,
        "workspace context exposes semantic roots without exposing raw workspace storage"
    )
    try expect(
        projectContext.defaultRootIdentifier == projectID,
        "workspace context exposes the default root identifier of its authority snapshot"
    )
    try expect(
        projectContext.grants == [projectGrant],
        "workspace context exposes semantic grants without exposing grant records"
    )
    try expect(
        projectContext.grant(
            identifier: projectGrant.id
        ) == projectGrant,
        "workspace context resolves a semantic grant by identifier"
    )
    try expect(
        projectContext.status(
            of: projectGrant.id
        ) == .active,
        "workspace context exposes effective grant status without exposing internal grant state"
    )

    let defaultContext = try workspace.context()

    try expect(
        defaultContext.rootIdentifier == projectID,
        "workspace context records the resolved default root when no root is explicitly supplied"
    )

    let initialAuthorization = try projectContext.authorize(
        "base.txt",
        capability: .read
    )

    let externalRoot = PathAccessRoot(
        id: externalID,
        label: "External",
        scope: try PathAccessScope(
            root: externalURL,
            policy: .defaults.workspace
        )
    )
    let externalGrant = try WorkspaceGrant(
        id: try WorkspaceGrantIdentifier(
            "external-read-a"
        ),
        rootIdentifier: externalID,
        capabilities: [
            .read,
        ]
    )

    let registrationA = try workspace.install { installation in
        installation.install(
            externalRoot
        )
        installation.install(
            externalGrant
        )
    }

    let externalGrantB = try WorkspaceGrant(
        id: try WorkspaceGrantIdentifier(
            "external-read-b"
        ),
        rootIdentifier: externalID,
        capabilities: [
            .read,
        ]
    )
    let registrationB = try workspace.install(
        externalGrantB
    )

    _ = try workspace.invalidate(
        registrationA
    )

    try expect(
        workspace.root(
            identifier: externalID
        ) != nil,
        "invalidating a root-owning registration preserves its root while another active grant depends on it"
    )

    _ = try workspace.invalidate(
        registrationB
    )

    try expect(
        workspace.root(
            identifier: externalID
        ) == nil,
        "workspace reclaims a registration-owned root after its final active dependent authority ends"
    )

    var staleRevisionRejected = false

    do {
        try workspace.requireCurrent(
            initialAuthorization
        )
    } catch WorkspaceError.stale_authorization {
        staleRevisionRejected = true
    }

    try expect(
        staleRevisionRejected,
        "workspace mutations stale previously issued authorization evidence"
    )

    _ = try workspace.reauthorize(
        initialAuthorization
    )

    let boundedSnapshot = try requireSnapshot(
        boundedURL
    )
    let boundedRange = try LineRange(
        start: 2,
        end: 4
    )
    let boundedSelection = PathSelection(
        [
            .literal("bounded.txt"),
        ],
        terminalHint: .file,
        content: .lines(
            boundedRange
        )
    )
    let wrongSnapshot = try requireSnapshot(
        baseURL
    )
    let wrongScope = try WorkspaceScope.resolved(
        boundedSelection,
        sourceSnapshot: wrongSnapshot
    )
    let wrongGrant = try WorkspaceGrant(
        id: try WorkspaceGrantIdentifier(
            "bounded-wrong-source"
        ),
        rootIdentifier: projectID,
        scope: wrongScope,
        capabilities: [
            .edit,
        ]
    )
    var wrongSourceBindingRejected = false

    do {
        _ = try workspace.install(
            wrongGrant
        )
    } catch WorkspaceError.source_snapshot_path_mismatch {
        wrongSourceBindingRejected = true
    }

    try expect(
        wrongSourceBindingRejected,
        "workspace installation binds resolved source evidence to the grant's selected path"
    )

    let boundedScope = try WorkspaceScope.resolved(
        boundedSelection,
        sourceSnapshot: boundedSnapshot
    )
    let boundedGrant = try WorkspaceGrant(
        id: try WorkspaceGrantIdentifier(
            "bounded-edit"
        ),
        rootIdentifier: projectID,
        scope: boundedScope,
        capabilities: [
            .edit,
        ]
    )
    let boundedRegistration = try workspace.install(
        boundedGrant
    )

    let boundedContext = try workspace.context()
    let boundedAuthorization = try boundedContext.authorize(
        "bounded.txt",
        capability: .edit,
        lineRange: try LineRange(
            start: 3,
            end: 3
        ),
        sourceSnapshot: boundedSnapshot
    )

    try boundedContext.requireCurrent(
        boundedAuthorization,
        currentSourceSnapshot: boundedSnapshot
    )

    var outsideRangeRejected = false

    do {
        _ = try boundedContext.authorize(
            "bounded.txt",
            capability: .edit,
            lineRange: try LineRange(
                start: 1,
                end: 2
            ),
            sourceSnapshot: boundedSnapshot
        )
    } catch {
        outsideRangeRejected = true
    }

    try expect(
        outsideRangeRejected,
        "content-scoped authority rejects ranges outside the resolved extent"
    )

    var impossibleCapabilityRejected = false

    do {
        _ = try WorkspaceGrant(
            id: try WorkspaceGrantIdentifier(
                "bounded-write"
            ),
            rootIdentifier: projectID,
            scope: boundedScope,
            capabilities: [
                .write,
            ]
        )
    } catch WorkspaceError.invalid_content_capabilities {
        impossibleCapabilityRejected = true
    }

    try expect(
        impossibleCapabilityRejected,
        "whole-file capabilities cannot be represented as content-range authority"
    )

    var directoryContentRejected = false

    do {
        _ = try WorkspaceScope.resolved(
            PathSelection(
                [
                    .literal("bounded.txt"),
                ],
                terminalHint: .directory,
                content: .lines(
                    boundedRange
                )
            ),
            sourceSnapshot: boundedSnapshot
        )
    } catch WorkspaceError.directory_content_scope {
        directoryContentRejected = true
    }

    try expect(
        directoryContentRejected,
        "directory selections cannot retain file content authority"
    )

    try "changed\nsource\ncontents\n".write(
        to: boundedURL,
        atomically: true,
        encoding: .utf8
    )
    let changedSnapshot = try requireSnapshot(
        boundedURL
    )
    var staleSourceRejected = false

    do {
        _ = try workspace.reauthorize(
            boundedAuthorization,
            currentSourceSnapshot: changedSnapshot
        )
    } catch WorkspaceError.stale_source_snapshot {
        staleSourceRejected = true
    }

    try expect(
        staleSourceRejected,
        "resolved content authority refuses source evidence from a changed file"
    )

    let expiringGrant = try WorkspaceGrant(
        id: try WorkspaceGrantIdentifier(
            "expired-read"
        ),
        rootIdentifier: projectID,
        capabilities: [
            .read,
        ],
        expiresAt: Date(
            timeIntervalSince1970: 100
        )
    )
    _ = try workspace.install(
        expiringGrant
    )
    let beforeRevalidation = workspace.revision
    _ = try workspace.revalidate(
        at: Date(
            timeIntervalSince1970: 200
        )
    )

    try expect(
        workspace.revision > beforeRevalidation,
        "temporal revalidation advances authority revision when grant state changes"
    )
    try expect(
        workspace.status(
            of: expiringGrant.id,
            at: Date(
                timeIntervalSince1970: 200
            )
        ) == .expired(
            Date(
                timeIntervalSince1970: 100
            )
        ),
        "revalidation canonicalizes elapsed grants into expired state"
    )

    _ = try workspace.invalidate(
        boundedRegistration
    )

    try expect(
        workspace.root(
            identifier: projectID
        ) != nil,
        "registration cleanup never removes roots that were part of the workspace's initial authority state"
    )

    let encoded = try JSONEncoder().encode(
        workspace
    )
    let decoded = try JSONDecoder().decode(
        Workspace.self,
        from: encoded
    )

    try expect(
        decoded == workspace,
        "workspace roots, grants, registrations, states, source evidence, and revision survive durable round trip"
    )
}

try workspaceAuthorityHardening()
print("WorkspaceTests: passed")
