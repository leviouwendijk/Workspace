import Foundation
import Path
import Position
import Selection

public enum WorkspaceCapability:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case list
    case read
    case write
    case edit
    case scan
    case create_directory
}

public struct WorkspaceGrantIdentifier:
    Sendable,
    Hashable,
    Codable,
    CustomStringConvertible
{
    public let rawValue: String

    public init(
        _ rawValue: String
    ) throws {
        let rawValue = rawValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !rawValue.isEmpty else {
            throw WorkspaceError.empty_grant_identifier
        }

        self.rawValue = rawValue
    }

    public var description: String {
        rawValue
    }

    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.singleValueContainer()
        try self.init(
            container.decode(
                String.self
            )
        )
    }

    public func encode(
        to encoder: Encoder
    ) throws {
        var container = encoder.singleValueContainer()
        try container.encode(
            rawValue
        )
    }
}

public struct WorkspaceRevision:
    Sendable,
    Codable,
    Hashable,
    Comparable,
    RawRepresentable
{
    public let rawValue: UInt64

    public init(
        rawValue: UInt64
    ) {
        self.rawValue = rawValue
    }

    public static let initial = Self(
        rawValue: 0
    )

    public static func < (
        lhs: Self,
        rhs: Self
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    func advanced() throws -> Self {
        let result = rawValue.addingReportingOverflow(
            1
        )

        guard !result.overflow else {
            throw WorkspaceError.revision_overflow
        }

        return Self(
            rawValue: result.partialValue
        )
    }
}

public enum WorkspaceGrantState:
    Sendable,
    Codable,
    Hashable
{
    case active
    case invalidated(WorkspaceRevision)
}

public enum WorkspaceGrantStatus:
    Sendable,
    Codable,
    Hashable
{
    case active
    case expired(Date)
    case invalidated(WorkspaceRevision)
}

public struct WorkspaceScope:
    Sendable,
    Codable,
    Hashable
{
    private enum Storage:
        Sendable,
        Codable,
        Hashable
    {
        case root
        case selection(PathSelection)
    }

    private let storage: Storage

    private init(
        storage: Storage
    ) {
        self.storage = storage
    }

    public static let root = Self(
        storage: .root
    )

    public static func selection(
        _ selection: PathSelection
    ) throws -> Self {
        if let content = selection.content {
            switch content {
            case .anchor:
                throw WorkspaceError.dynamic_content_scope

            case .lines, .point, .span:
                break
            }
        }

        return Self(
            storage: .selection(
                selection
            )
        )
    }

    public var pathSelection: PathSelection? {
        switch storage {
        case .root:
            return nil

        case .selection(let selection):
            return selection
        }
    }

    public init(
        from decoder: Decoder
    ) throws {
        let storage = try Storage(
            from: decoder
        )

        switch storage {
        case .root:
            self = .root

        case .selection(let selection):
            self = try .selection(
                selection
            )
        }
    }

    public func encode(
        to encoder: Encoder
    ) throws {
        try storage.encode(
            to: encoder
        )
    }

    func contains(
        _ path: DescendantPath,
        lineRange: LineRange?
    ) -> Bool {
        switch storage {
        case .root:
            return true

        case .selection(let selection):
            guard selection.pattern.matches(
                path.relative
            ) else {
                return false
            }

            guard let content = selection.content else {
                return true
            }
            guard let allowedRange = content.lineRange,
                  let lineRange
            else {
                return false
            }

            return allowedRange.contains(
                lineRange
            )
        }
    }
}

public struct WorkspaceGrant:
    Sendable,
    Codable,
    Hashable,
    Identifiable
{
    public let id: WorkspaceGrantIdentifier
    public let rootIdentifier: PathAccessRootIdentifier
    public let scope: WorkspaceScope
    public let capabilities: Set<WorkspaceCapability>
    public let expiresAt: Date?

    public init(
        id: WorkspaceGrantIdentifier,
        rootIdentifier: PathAccessRootIdentifier,
        scope: WorkspaceScope = .root,
        capabilities: Set<WorkspaceCapability>,
        expiresAt: Date? = nil
    ) throws {
        guard !capabilities.isEmpty else {
            throw WorkspaceError.empty_capabilities(
                id
            )
        }

        self.id = id
        self.rootIdentifier = rootIdentifier
        self.scope = scope
        self.capabilities = capabilities
        self.expiresAt = expiresAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case rootIdentifier
        case scope
        case capabilities
        case expiresAt
    }

    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        try self.init(
            id: container.decode(
                WorkspaceGrantIdentifier.self,
                forKey: .id
            ),
            rootIdentifier: container.decode(
                PathAccessRootIdentifier.self,
                forKey: .rootIdentifier
            ),
            scope: container.decode(
                WorkspaceScope.self,
                forKey: .scope
            ),
            capabilities: container.decode(
                Set<WorkspaceCapability>.self,
                forKey: .capabilities
            ),
            expiresAt: container.decodeIfPresent(
                Date.self,
                forKey: .expiresAt
            )
        )
    }

    public func isActive(
        at date: Date = Date()
    ) -> Bool {
        guard let expiresAt else {
            return true
        }

        return date < expiresAt
    }
}

public struct WorkspaceGrantRecord:
    Sendable,
    Codable,
    Hashable
{
    public let grant: WorkspaceGrant
    public let state: WorkspaceGrantState

    public init(
        grant: WorkspaceGrant,
        state: WorkspaceGrantState = .active
    ) {
        self.grant = grant
        self.state = state
    }

    public func status(
        at date: Date = Date()
    ) -> WorkspaceGrantStatus {
        switch state {
        case .invalidated(let revision):
            return .invalidated(
                revision
            )

        case .active:
            guard let expiresAt = grant.expiresAt,
                  date >= expiresAt
            else {
                return .active
            }

            return .expired(
                expiresAt
            )
        }
    }
}
