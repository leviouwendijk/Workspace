import Path

public struct WorkspaceContext: Sendable {
    public let workspace: Workspace
    public let location: WorkspaceLocation?

    init(
        workspace: Workspace,
        location: WorkspaceLocation?
    ) {
        self.workspace = workspace
        self.location = location
    }
}

public extension Workspace {
    func context() -> WorkspaceContext {
        WorkspaceContext(
            workspace: self,
            location: nil
        )
    }

    func context(
        at rawPath: String,
        rootIdentifier: PathAccessRootIdentifier? = nil
    ) throws -> WorkspaceContext {
        WorkspaceContext(
            workspace: self,
            location: try location(
                rawPath,
                rootIdentifier: rootIdentifier
            )
        )
    }

    func context(
        at path: DescendantPath,
        rootIdentifier: PathAccessRootIdentifier? = nil
    ) throws -> WorkspaceContext {
        WorkspaceContext(
            workspace: self,
            location: try location(
                path,
                rootIdentifier: rootIdentifier
            )
        )
    }
}
