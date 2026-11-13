import Foundation
import Writers

/// A Workspace-authorized participant of the process-owned mutation coordinator.
/// No publication, rollback, journal, or bulk-cancellation authority is exposed.
public struct WorkspaceCoordinatedSubmission: Sendable {
    /// Owner-granted publication of this participant's own submissions. The
    /// owner decides who may publish on submit; without a grant, submissions
    /// stay staged under their claims until the owner publishes them.
    public typealias Publication =
        @Sendable (UUID) async throws -> StandardMutationPublication?

    private let participant: StandardMutationParticipant
    private let publication: Publication?

    public var id: UUID { participant.id }

    /// Whether submissions are published as soon as they are admitted.
    public var publishesOnSubmit: Bool { publication != nil }

    public init(
        participant: StandardMutationParticipant,
        publication: Publication? = nil
    ) {
        self.participant = participant
        self.publication = publication
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
