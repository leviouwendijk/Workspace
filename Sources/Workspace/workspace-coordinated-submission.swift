import Foundation
import Writers

public enum WorkspaceCoordinatedSubmissionError: Error, Sendable, LocalizedError {
    case recovery_not_granted

    public var errorDescription: String? {
        switch self {
        case .recovery_not_granted:
            return "This session cannot request mutation recovery."
        }
    }
}

/// A Workspace-authorized participant of the process-owned mutation coordinator.
/// No publication, rollback, journal, or bulk-cancellation authority is exposed.
/// Recovery of a blocked coordinator is exposed only when the owner grants it,
/// and the owner decides how it is approved.
public struct WorkspaceCoordinatedSubmission: Sendable {
    /// Owner-granted recovery: read why the coordinator is blocked, and ask
    /// the owner to unblock it once the filesystem has been reconciled.
    public struct Recovery: Sendable {
        public let cause: @Sendable () async -> StandardMutationRecoveryCause?
        public let recover: @Sendable () async throws -> Bool

        public init(
            cause: @escaping @Sendable () async -> StandardMutationRecoveryCause?,
            recover: @escaping @Sendable () async throws -> Bool
        ) {
            self.cause = cause
            self.recover = recover
        }
    }

    /// Owner-granted publication of this participant's own submissions. The
    /// owner decides who may publish on submit; without a grant, submissions
    /// stay staged under their claims until the owner publishes them.
    public typealias Publication =
        @Sendable (UUID) async throws -> StandardMutationPublication?

    private let participant: StandardMutationParticipant
    private let publication: Publication?
    private let recovery: Recovery?

    public var id: UUID { participant.id }

    /// Whether submissions are published as soon as they are admitted.
    public var publishesOnSubmit: Bool { publication != nil }

    public init(
        participant: StandardMutationParticipant,
        publication: Publication? = nil,
        recovery: Recovery? = nil
    ) {
        self.participant = participant
        self.publication = publication
        self.recovery = recovery
    }

    /// Whether the owner granted recovery to this participant.
    public var canRequestRecovery: Bool { recovery != nil }

    /// Why the coordinator refuses changes; nil when it does not, or when
    /// recovery was not granted.
    public func recoveryCause() async -> StandardMutationRecoveryCause? {
        await recovery?.cause()
    }

    /// Unblocks the coordinator through the owner. Returns whether it was blocked.
    @discardableResult
    public func recover() async throws -> Bool {
        guard let recovery else {
            throw WorkspaceCoordinatedSubmissionError.recovery_not_granted
        }
        return try await recovery.recover()
    }

    /// Accept the *same* prepared plan used by the calling tool. Every source
    /// and destination receives Workspace authorization before Writers admits
    /// any reservations. This matches MutateFiles' existing write/read policy;
    /// more granular .edit grants are a separate authorization-policy migration.
    @discardableResult
    public func submit(
        _ plan: StandardMutationPlan,
        in workspace: WorkspaceContext
    ) async throws -> StandardMutationSubmission {
        for planned in plan.entries {
            switch planned.entry {
            case .copy(let operation):
                _ = try workspace.authorize(
                    operation.source.path, capability: .read
                )
                _ = try workspace.authorize(
                    operation.destination.path, capability: .write
                )
            case .move(let operation):
                _ = try workspace.authorize(
                    operation.source.path, capability: .write
                )
                _ = try workspace.authorize(
                    operation.destination.path, capability: .write
                )
            case .create_text, .replace_text, .edit_text, .delete:
                _ = try workspace.authorize(
                    planned.target.path, capability: .write
                )
            }
        }
        return try await participant.submit(plan)
    }

    /// Publishes an admitted submission when the owner granted it; nil when
    /// the submission stays staged.
    public func publish(
        _ submission: StandardMutationSubmission
    ) async throws -> StandardMutationPublication? {
        try await publication?(submission.id)
    }

    /// This participant's own staged state of a resource, so reads see
    /// changes it staged but has not published. nil: no staged change.
    public func stagedState(
        at url: URL
    ) async throws -> StandardResourceState? {
        try await participant.staged_state(at: url)
    }

    public func withdraw(_ submission_id: UUID) async throws {
        try await participant.withdraw(submission_id)
    }

    public func close() async throws {
        try await participant.close()
    }
}
