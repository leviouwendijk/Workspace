import Foundation
import Path
import Position
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

func dynamicAuthorityState() throws {
    let fileManager = FileManager.default
    let fixtureRoot = fileManager.temporaryDirectory
        .appendingPathComponent(
            "workspace-foundation-\(UUID().uuidString)",
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

    try "base\n".write(
        to: projectURL.appendingPathComponent(
            "base.txt"
        ),
        atomically: true,
        encoding: .utf8
    )
    try "external\n".write(
        to: externalURL.appendingPathComponent(
            "external.txt"
        ),
        atomically: true,
        encoding: .utf8
    )
    try "one\ntwo\nthree\nfour\nfive\n".write(
        to: projectURL.appendingPathComponent(
            "bounded.txt"
        ),
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

    var workspace = try Workspace(
        roots: [
            projectRoot,
        ],
        grants: [
            projectGrant,
        ]
    )

    let initialAuthorization = try workspace.authorize(
        WorkspaceAuthorizationRequest(
            rootIdentifier: projectID,
            path: "base.txt",
            capability: .read
        )
    )

    try expect(
        initialAuthorization.revision == .initial,
        "initial authorization records initial workspace revision"
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
            "external-read"
        ),
        rootIdentifier: externalID,
        capabilities: [
            .read,
        ]
    )

    let externalRegistration = try workspace.update { update in
        update.install(
            externalRoot
        )
        update.install(
            externalGrant
        )
    }

    try expect(
        externalRegistration.roots == [
            externalID,
        ],
        "transaction registration records installed root"
    )
    try expect(
        externalRegistration.grants == [
            externalGrant.id,
        ],
        "transaction registration records installed grant"
    )
    try expect(
        workspace.revision == WorkspaceRevision(
            rawValue: 1
        ),
        "atomic installation advances workspace revision once"
    )

    _ = try workspace.authorize(
        WorkspaceAuthorizationRequest(
            rootIdentifier: externalID,
            path: "external.txt",
            capability: .read
        )
    )

    var staleRejected = false

    do {
        try workspace.requireCurrent(
            initialAuthorization
        )
    } catch WorkspaceError.stale_authorization {
        staleRejected = true
    }

    try expect(
        staleRejected,
        "authority mutation makes previous authorization evidence stale"
    )

    let refreshedAuthorization = try workspace.reauthorize(
        initialAuthorization
    )

    try expect(
        refreshedAuthorization.revision == workspace.revision,
        "reauthorization binds evidence to current revision"
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
    let boundedGrant = try WorkspaceGrant(
        id: try WorkspaceGrantIdentifier(
            "bounded-edit"
        ),
        rootIdentifier: projectID,
        scope: try .selection(
            boundedSelection
        ),
        capabilities: [
            .edit,
        ]
    )
    let boundedRegistration = try workspace.install(
        boundedGrant
    )

    _ = try workspace.authorize(
        WorkspaceAuthorizationRequest(
            rootIdentifier: projectID,
            path: "bounded.txt",
            capability: .edit,
            lineRange: try LineRange(
                start: 3,
                end: 3
            )
        )
    )

    var outsideRangeRejected = false

    do {
        _ = try workspace.authorize(
            WorkspaceAuthorizationRequest(
                rootIdentifier: projectID,
                path: "bounded.txt",
                capability: .edit,
                lineRange: try LineRange(
                    start: 1,
                    end: 2
                )
            )
        )
    } catch {
        outsideRangeRejected = true
    }

    try expect(
        outsideRangeRejected,
        "content-scoped grant rejects edits outside its line range"
    )

    var wholeFileRejected = false

    do {
        _ = try workspace.authorize(
            WorkspaceAuthorizationRequest(
                rootIdentifier: projectID,
                path: "bounded.txt",
                capability: .edit
            )
        )
    } catch {
        wholeFileRejected = true
    }

    try expect(
        wholeFileRejected,
        "content-scoped grant cannot authorize whole-file edit"
    )

    let beforeFailedUpdate = workspace
    let missingRootID = PathAccessRootIdentifier(
        rawValue: "missing"
    )
    let invalidGrant = try WorkspaceGrant(
        id: try WorkspaceGrantIdentifier(
            "invalid-root-grant"
        ),
        rootIdentifier: missingRootID,
        capabilities: [
            .read,
        ]
    )
    var failedTransaction = false

    do {
        _ = try workspace.update { update in
            update.install(
                invalidGrant
            )
        }
    } catch {
        failedTransaction = true
    }

    try expect(
        failedTransaction,
        "grant for missing root is rejected"
    )
    try expect(
        workspace == beforeFailedUpdate,
        "failed workspace update commits no partial authority state"
    )

    _ = try workspace.invalidate(
        externalRegistration
    )

    try expect(
        workspace.root(
            identifier: externalID
        ) == nil,
        "invalidating registration removes now-unused installed root"
    )
    try expect(
        workspace.status(
            of: externalGrant.id
        ) != .active,
        "invalidating registration revokes installed grant"
    )

    var externalRejected = false

    do {
        _ = try workspace.authorize(
            WorkspaceAuthorizationRequest(
                rootIdentifier: externalID,
                path: "external.txt",
                capability: .read
            )
        )
    } catch {
        externalRejected = true
    }

    try expect(
        externalRejected,
        "revoked registration no longer contributes authority"
    )

    _ = try workspace.invalidate(
        boundedRegistration
    )

    try expect(
        workspace.root(
            identifier: projectID
        ) != nil,
        "invalidating grant-only registration preserves pre-existing root"
    )

    _ = try workspace.authorize(
        WorkspaceAuthorizationRequest(
            rootIdentifier: projectID,
            path: "base.txt",
            capability: .read
        )
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
        "workspace dynamic authority state survives durable round trip"
    )
}

try dynamicAuthorityState()
print("WorkspaceTests: passed")
