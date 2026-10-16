import IO
import Writers

/// Execution policy shared by contexts derived from one authorized workspace.
/// The caller owns its lifetime, including any coordinated editing state.
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
    case coordinated(StandardEditCoordinator)
}

public enum WorkspaceExecutionError: Error, Sendable {
    case coordinatedMutationRequiresSubmission
}
