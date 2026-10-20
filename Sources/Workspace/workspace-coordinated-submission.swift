import Foundation
import Path
import Position
import Readers
import Writers

/// A participant capability. The owning session retains StandardEditCoordinator;
/// this wrapper never exposes seal/construct/write or the raw mutator.
public struct WorkspaceCoordinatedSubmission: Sendable {
    private let mutator: StandardEditMutator

    public var id: UUID { mutator.id }

    public init(mutator: StandardEditMutator) {
        self.mutator = mutator
    }

    /// A scoped acquisition must be authorized for edits before a lease exists.
    /// Insertion positions deliberately require whole-file .edit authority until
    /// the Workspace content-scope policy models insertion boundaries explicitly.
    public func acquire(
        in workspace: WorkspaceContext,
        at path: String,
        scope: StandardEditScope,
        sourceSnapshot: FileReadSnapshot? = nil
    ) async throws -> WorkspaceEditAcquisition {
        let authorizations: [WorkspaceAuthorization]
        switch scope {
        case .file, .insertions:
            authorizations = [try workspace.authorize(
                path,
                capability: .edit,
                sourceSnapshot: sourceSnapshot
            )]
        case .lines(let ranges):
            guard !ranges.isEmpty else {
                throw WorkspaceExecutionError.empty_coordinated_scope
            }
            authorizations = try ranges.map { range in
                try workspace.authorize(
                    path,
                    capability: .edit,
                    lineRange: range,
                    sourceSnapshot: sourceSnapshot
                )
            }
        }
        guard let first = authorizations.first else {
            throw WorkspaceExecutionError.empty_coordinated_scope
        }
        let receipt = try await mutator.acquire(
            file: first.authorizedPath.absoluteURL,
            scope: scope
        )
        return WorkspaceEditAcquisition(
            receipt: receipt,
            authorizations: authorizations,
            rootIdentifier: workspace.rootIdentifier
        )
    }

    /// Recheck authority at submission; the coordinator separately enforces
    /// mutator ownership, acquisition scope, and snapshot compatibility.
    @discardableResult
    public func submit(
        _ operation: StandardCoordinatedEditOperation,
        acquisition: WorkspaceEditAcquisition,
        in workspace: WorkspaceContext,
        currentSourceSnapshot: FileReadSnapshot? = nil,
        comment: String? = nil
    ) async throws -> StandardEditMutation {
        guard acquisition.rootIdentifier == workspace.rootIdentifier else {
            throw WorkspaceExecutionError.coordinated_context_root_mismatch
        }
        guard acquisition.receipt.mutator_id == mutator.id else {
            throw StandardEditCoordinationError.acquisition_not_owned(
                acquisition.receipt.id
            )
        }
        for authorization in acquisition.authorizations {
            try workspace.requireCurrent(
                authorization,
                currentSourceSnapshot: currentSourceSnapshot
            )
        }
        return try await mutator.submit(
            acquisition: acquisition.receipt,
            operation: operation,
            comment: comment
        )
    }

    public func stop() async throws {
        try await mutator.stop()
    }

    public func abort(comment: String? = nil) async {
        await mutator.abort(comment: comment)
    }
}

/// A receipt is only created by an authorized acquisition in Workspace.
public struct WorkspaceEditAcquisition: Sendable {
    public var id: UUID { receipt.id }
    public var file: URL { receipt.file }
    public var scope: StandardEditScope { receipt.scope }
    public var state: StandardEditAcquisitionState { receipt.state }

    fileprivate let receipt: StandardEditAcquisition
    fileprivate let authorizations: [WorkspaceAuthorization]
    fileprivate let rootIdentifier: PathAccessRootIdentifier

    fileprivate init(
        receipt: StandardEditAcquisition,
        authorizations: [WorkspaceAuthorization],
        rootIdentifier: PathAccessRootIdentifier
    ) {
        self.receipt = receipt
        self.authorizations = authorizations
        self.rootIdentifier = rootIdentifier
    }
}
