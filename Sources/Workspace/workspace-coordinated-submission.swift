import Foundation
import Writers

/// A Workspace-authorized participant of the process-owned mutation coordinator.
/// No publication, rollback, journal, or bulk-cancellation authority is exposed.
public struct WorkspaceCoordinatedSubmission: Sendable {
    private let participant: StandardMutationParticipant

    public var id: UUID { participant.id }

    public init(participant: StandardMutationParticipant) {
        self.participant = participant
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

    public func withdraw(_ submission_id: UUID) async throws {
        try await participant.withdraw(submission_id)
    }

    public func close() async throws {
        try await participant.close()
    }
}
