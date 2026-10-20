import IO
import Writers

/// Execution policy shared by contexts derived from one authorized workspace.
/// The session retains the coordinator. Tools receive only an authorized participant.
public struct WorkspaceExecution: Sendable {
    public let io: IO
    public let mutations: WorkspaceMutationMode

    public init(
        io: IO,
        mutations: WorkspaceMutationMode
    ) {
        self.io = io
        self.mutations = mutations
    }

    /// Immediate filesystem mutation paths must not bypass a coordinated session.
    public func requireImmediateMutation() throws {
        guard case .immediate = mutations else {
            throw WorkspaceExecutionError.coordinatedMutationRequiresSubmission
        }
    }
}

public enum WorkspaceMutationMode: Sendable {
    case immediate
    case coordinated(WorkspaceCoordinatedSubmission)
}

public enum WorkspaceExecutionError: Error, Sendable {
    case coordinatedMutationRequiresSubmission
    case empty_coordinated_scope
    case coordinated_context_root_mismatch
}
