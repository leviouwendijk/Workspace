import Foundation
import Path
import Position

public struct Workspace: Sendable, Codable, Hashable {
    private var paths: PathAccessController
    private var grantRecords: [WorkspaceGrantIdentifier: WorkspaceGrantRecord]

    public private(set) var revision: WorkspaceRevision

    public init(
        roots: [PathAccessRoot] = [],
        defaultRootIdentifier: PathAccessRootIdentifier? = nil,
        grants: [WorkspaceGrant] = []
    ) throws {
        try self.init(
            roots: roots,
            defaultRootIdentifier: defaultRootIdentifier,
            records: grants.map {
                WorkspaceGrantRecord(
                    grant: $0,
                    state: .active
                )
            },
            revision: .initial
        )
    }

    private init(
        roots: [PathAccessRoot],
        defaultRootIdentifier: PathAccessRootIdentifier?,
        records: [WorkspaceGrantRecord],
        revision: WorkspaceRevision
    ) throws {
        var rootIdentifiers: Set<PathAccessRootIdentifier> = []

        for root in roots {
            guard rootIdentifiers.insert(root.id).inserted else {
                throw WorkspaceError.duplicate_root(
                    root.id
                )
            }
        }

        if let defaultRootIdentifier,
           !rootIdentifiers.contains(defaultRootIdentifier)
        {
            throw WorkspaceError.root_not_found(
                defaultRootIdentifier
            )
        }

        let paths = PathAccessController(
            roots: roots,
            defaultRootIdentifier: defaultRootIdentifier
        )
        var mappedRecords: [
            WorkspaceGrantIdentifier: WorkspaceGrantRecord
        ] = [:]

        for record in records {
            let identifier = record.grant.id

            guard mappedRecords[identifier] == nil else {
                throw WorkspaceError.duplicate_grant(
                    identifier
                )
            }

            if case .active = record.state,
               paths.roots[record.grant.rootIdentifier] == nil
            {
                throw WorkspaceError.grant_root_not_installed(
                    grant: identifier,
                    root: record.grant.rootIdentifier
                )
            }

            mappedRecords[identifier] = record
        }

        self.paths = paths
        self.grantRecords = mappedRecords
        self.revision = revision
    }

    private enum CodingKeys: String, CodingKey {
        case roots
        case defaultRootIdentifier
        case grants
        case revision
    }

    public init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        try self.init(
            roots: container.decode(
                [PathAccessRoot].self,
                forKey: .roots
            ),
            defaultRootIdentifier: container.decodeIfPresent(
                PathAccessRootIdentifier.self,
                forKey: .defaultRootIdentifier
            ),
            records: container.decode(
                [WorkspaceGrantRecord].self,
                forKey: .grants
            ),
            revision: container.decode(
                WorkspaceRevision.self,
                forKey: .revision
            )
        )
    }

    public func encode(
        to encoder: Encoder
    ) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(
            roots,
            forKey: .roots
        )
        try container.encodeIfPresent(
            defaultRootIdentifier,
            forKey: .defaultRootIdentifier
        )
        try container.encode(
            grants,
            forKey: .grants
        )
        try container.encode(
            revision,
            forKey: .revision
        )
    }
}

public extension Workspace {
    var roots: [PathAccessRoot] {
        paths.roots.values.sorted {
            $0.id.rawValue < $1.id.rawValue
        }
    }

    var rootIdentifiers: [PathAccessRootIdentifier] {
        paths.rootIdentifiers
    }

    var defaultRootIdentifier: PathAccessRootIdentifier? {
        paths.defaultRootIdentifier
    }

    var grants: [WorkspaceGrantRecord] {
        grantRecords.values.sorted {
            $0.grant.id.rawValue < $1.grant.id.rawValue
        }
    }

    func root(
        identifier: PathAccessRootIdentifier
    ) -> PathAccessRoot? {
        paths.roots[identifier]
    }

    func grant(
        identifier: WorkspaceGrantIdentifier
    ) -> WorkspaceGrantRecord? {
        grantRecords[identifier]
    }

    func status(
        of identifier: WorkspaceGrantIdentifier,
        at date: Date = Date()
    ) -> WorkspaceGrantStatus? {
        grantRecords[identifier]?.status(
            at: date
        )
    }
}

public extension Workspace {
    @discardableResult
    mutating func install(
        _ root: PathAccessRoot
    ) throws -> WorkspaceRegistration {
        try update { update in
            update.install(root)
        }
    }

    @discardableResult
    mutating func install(
        _ grant: WorkspaceGrant
    ) throws -> WorkspaceRegistration {
        try update { update in
            update.install(grant)
        }
    }

    @discardableResult
    mutating func replace(
        _ grant: WorkspaceGrant
    ) throws -> WorkspaceRevision {
        try update { update in
            update.replace(grant)
        }.revision
    }

    @discardableResult
    mutating func invalidate(
        _ identifier: WorkspaceGrantIdentifier
    ) throws -> WorkspaceRevision {
        try update { update in
            update.invalidate(identifier)
        }.revision
    }

    @discardableResult
    mutating func removeRoot(
        _ identifier: PathAccessRootIdentifier
    ) throws -> WorkspaceRevision {
        try update { update in
            update.removeRoot(identifier)
        }.revision
    }

    @discardableResult
    mutating func update(
        _ body: (inout WorkspaceUpdate) throws -> Void
    ) throws -> WorkspaceRegistration {
        var update = WorkspaceUpdate()
        try body(&update)

        return try apply(
            update
        )
    }

    @discardableResult
    mutating func invalidate(
        _ registration: WorkspaceRegistration
    ) throws -> WorkspaceRevision {
        let registeredGrants = Set(
            registration.grants
        )
        let removableRoots = registration.roots.filter { rootIdentifier in
            guard paths.roots[rootIdentifier] != nil else {
                return false
            }

            return !grantRecords.values.contains { record in
                guard case .active = record.state else {
                    return false
                }

                return record.grant.rootIdentifier == rootIdentifier
                    && !registeredGrants.contains(
                        record.grant.id
                    )
            }
        }

        let grantsToInvalidate = registration.grants.filter {
            grantRecords[$0] != nil
        }

        return try update { update in
            for identifier in grantsToInvalidate {
                update.invalidate(
                    identifier
                )
            }

            for identifier in removableRoots {
                update.removeRoot(
                    identifier
                )
            }
        }.revision
    }
}

public extension Workspace {
    func authorize(
        _ request: WorkspaceAuthorizationRequest,
        at date: Date = Date()
    ) throws -> WorkspaceAuthorization {
        let authorizedPath = try paths.authorize(
            request.path,
            rootIdentifier: request.rootIdentifier
        )

        return try authorization(
            for: authorizedPath,
            capability: request.capability,
            lineRange: request.lineRange,
            at: date
        )
    }

    func requireCurrent(
        _ authorization: WorkspaceAuthorization,
        at date: Date = Date()
    ) throws {
        guard authorization.revision == revision else {
            throw WorkspaceError.stale_authorization(
                authorized: authorization.revision,
                current: revision
            )
        }

        let currentPath = try paths.authorize(
            authorization.authorizedPath.path,
            rootIdentifier: authorization.authorizedPath.rootIdentifier
        )

        guard let record = grantRecords[authorization.grantIdentifier],
              record.status(at: date) == .active,
              record.grant.capabilities.contains(
                authorization.capability
              ),
              record.grant.rootIdentifier == currentPath.rootIdentifier,
              record.grant.scope.contains(
                currentPath.path,
                lineRange: authorization.lineRange
              )
        else {
            throw WorkspaceError.authorization_denied(
                root: authorization.authorizedPath.rootIdentifier,
                path: authorization.authorizedPath.presentationPath,
                capability: authorization.capability
            )
        }
    }

    func reauthorize(
        _ authorization: WorkspaceAuthorization,
        at date: Date = Date()
    ) throws -> WorkspaceAuthorization {
        let currentPath = try paths.authorize(
            authorization.authorizedPath.path,
            rootIdentifier: authorization.authorizedPath.rootIdentifier
        )

        return try self.authorization(
            for: currentPath,
            capability: authorization.capability,
            lineRange: authorization.lineRange,
            at: date
        )
    }
}

private extension Workspace {
    mutating func apply(
        _ update: WorkspaceUpdate
    ) throws -> WorkspaceRegistration {
        guard !update.operations.isEmpty else {
            return WorkspaceRegistration(
                roots: [],
                grants: [],
                revision: revision
            )
        }

        let candidateRevision = try revision.advanced()
        var candidatePaths = paths
        var candidateRecords = grantRecords
        var installedRoots: [PathAccessRootIdentifier] = []
        var installedGrants: [WorkspaceGrantIdentifier] = []
        var changed = false

        for operation in update.operations {
            switch operation {
            case .install_root(let root):
                guard candidatePaths.roots[root.id] == nil else {
                    throw WorkspaceError.duplicate_root(
                        root.id
                    )
                }

                candidatePaths = candidatePaths.installing(
                    root
                )
                installedRoots.append(
                    root.id
                )
                changed = true

            case .install_grant(let grant):
                guard candidateRecords[grant.id] == nil else {
                    throw WorkspaceError.duplicate_grant(
                        grant.id
                    )
                }
                guard candidatePaths.roots[grant.rootIdentifier] != nil else {
                    throw WorkspaceError.grant_root_not_installed(
                        grant: grant.id,
                        root: grant.rootIdentifier
                    )
                }

                candidateRecords[grant.id] = WorkspaceGrantRecord(
                    grant: grant,
                    state: .active
                )
                installedGrants.append(
                    grant.id
                )
                changed = true

            case .replace_grant(let grant):
                guard candidateRecords[grant.id] != nil else {
                    throw WorkspaceError.grant_not_found(
                        grant.id
                    )
                }
                guard candidatePaths.roots[grant.rootIdentifier] != nil else {
                    throw WorkspaceError.grant_root_not_installed(
                        grant: grant.id,
                        root: grant.rootIdentifier
                    )
                }

                candidateRecords[grant.id] = WorkspaceGrantRecord(
                    grant: grant,
                    state: .active
                )
                changed = true

            case .invalidate_grant(let identifier):
                guard let existing = candidateRecords[identifier] else {
                    throw WorkspaceError.grant_not_found(
                        identifier
                    )
                }

                guard case .active = existing.state else {
                    continue
                }

                candidateRecords[identifier] = WorkspaceGrantRecord(
                    grant: existing.grant,
                    state: .invalidated(
                        candidateRevision
                    )
                )
                changed = true

            case .remove_root(let identifier):
                guard candidatePaths.roots[identifier] != nil else {
                    throw WorkspaceError.root_not_found(
                        identifier
                    )
                }

                let activeGrantIdentifiers = candidateRecords.values.compactMap { record -> WorkspaceGrantIdentifier? in
                    guard case .active = record.state,
                          record.grant.rootIdentifier == identifier
                    else {
                        return nil
                    }

                    return record.grant.id
                }
                .sorted {
                    $0.rawValue < $1.rawValue
                }

                guard activeGrantIdentifiers.isEmpty else {
                    throw WorkspaceError.root_has_active_grants(
                        root: identifier,
                        grants: activeGrantIdentifiers
                    )
                }

                candidatePaths = candidatePaths.removingRoot(
                    identifier: identifier
                )
                changed = true
            }
        }

        guard changed else {
            return WorkspaceRegistration(
                roots: [],
                grants: [],
                revision: revision
            )
        }

        try Self.requireConsistency(
            paths: candidatePaths,
            records: candidateRecords
        )

        paths = candidatePaths
        grantRecords = candidateRecords
        revision = candidateRevision

        return WorkspaceRegistration(
            roots: installedRoots,
            grants: installedGrants,
            revision: candidateRevision
        )
    }

    static func requireConsistency(
        paths: PathAccessController,
        records: [WorkspaceGrantIdentifier: WorkspaceGrantRecord]
    ) throws {
        for (identifier, record) in records {
            guard identifier == record.grant.id else {
                throw WorkspaceError.grant_identifier_mismatch
            }

            guard case .active = record.state else {
                continue
            }

            guard paths.roots[record.grant.rootIdentifier] != nil else {
                throw WorkspaceError.grant_root_not_installed(
                    grant: identifier,
                    root: record.grant.rootIdentifier
                )
            }
        }
    }

    func authorization(
        for authorizedPath: AuthorizedPath,
        capability: WorkspaceCapability,
        lineRange: LineRange?,
        at date: Date
    ) throws -> WorkspaceAuthorization {
        let candidates = grantRecords.values.compactMap { record -> WorkspaceGrant? in
            guard record.status(at: date) == .active else {
                return nil
            }

            let grant = record.grant

            guard grant.rootIdentifier == authorizedPath.rootIdentifier,
                  grant.capabilities.contains(capability),
                  grant.scope.contains(
                    authorizedPath.path,
                    lineRange: lineRange
                  )
            else {
                return nil
            }

            return grant
        }
        .sorted {
            $0.id.rawValue < $1.id.rawValue
        }

        guard let grant = candidates.first else {
            throw WorkspaceError.authorization_denied(
                root: authorizedPath.rootIdentifier,
                path: authorizedPath.presentationPath,
                capability: capability
            )
        }

        return WorkspaceAuthorization(
            authorizedPath: authorizedPath,
            capability: capability,
            lineRange: lineRange,
            grantIdentifier: grant.id,
            revision: revision
        )
    }
}
