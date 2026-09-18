import Foundation
import Path
import Position
import Readers

public struct Workspace: Sendable, Codable, Hashable {
    var paths: PathAccessController
    private var grantRecords: [WorkspaceGrantIdentifier: WorkspaceGrantRecord]
    private var registrationRecords: [WorkspaceRegistrationIdentifier: WorkspaceRegistrationRecord]

    public private(set) var revision: WorkspaceRevision

    public init(
        roots: [PathAccessRoot] = [],
        defaultRootIdentifier: PathAccessRootIdentifier? = nil,
        grants: [WorkspaceGrant] = []
    ) throws {
        try self.init(
            roots: roots,
            defaultRootIdentifier: defaultRootIdentifier,
            grants: grants.map {
                WorkspaceGrantRecord(
                    grant: $0,
                    state: .active
                )
            },
            registrations: [],
            revision: .initial
        )
    }

    private init(
        roots: [PathAccessRoot],
        defaultRootIdentifier: PathAccessRootIdentifier?,
        grants: [WorkspaceGrantRecord],
        registrations: [WorkspaceRegistrationRecord],
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
        var mappedGrants: [WorkspaceGrantIdentifier: WorkspaceGrantRecord] = [:]
        var mappedRegistrations: [WorkspaceRegistrationIdentifier: WorkspaceRegistrationRecord] = [:]

        for record in grants {
            let identifier = record.grant.id

            guard mappedGrants[identifier] == nil else {
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

            mappedGrants[identifier] = record
        }

        for record in registrations {
            let identifier = record.registration.id

            guard mappedRegistrations[identifier] == nil else {
                throw WorkspaceError.registration_not_active(
                    identifier
                )
            }

            if case .active = record.state {
                for rootIdentifier in record.registration.roots {
                    guard paths.roots[rootIdentifier] != nil else {
                        throw WorkspaceError.root_not_found(
                            rootIdentifier
                        )
                    }
                }
            }

            mappedRegistrations[identifier] = record
        }

        try Self.requireConsistency(
            paths: paths,
            grants: mappedGrants,
            registrations: mappedRegistrations
        )

        self.paths = paths
        self.grantRecords = mappedGrants
        self.registrationRecords = mappedRegistrations
        self.revision = revision
    }

    private enum CodingKeys: String, CodingKey {
        case roots
        case defaultRootIdentifier
        case grants
        case registrations
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
            grants: container.decode(
                [WorkspaceGrantRecord].self,
                forKey: .grants
            ),
            registrations: container.decodeIfPresent(
                [WorkspaceRegistrationRecord].self,
                forKey: .registrations
            ) ?? [],
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
            registrations,
            forKey: .registrations
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

    var registrations: [WorkspaceRegistrationRecord] {
        registrationRecords.values.sorted {
            $0.registration.id.description < $1.registration.id.description
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

    func registration(
        identifier: WorkspaceRegistrationIdentifier
    ) -> WorkspaceRegistrationRecord? {
        registrationRecords[identifier]
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
        try install { installation in
            installation.install(
                root
            )
        }
    }

    @discardableResult
    mutating func install(
        _ grant: WorkspaceGrant
    ) throws -> WorkspaceRegistration {
        try install { installation in
            installation.install(
                grant
            )
        }
    }

    @discardableResult
    mutating func install(
        _ body: (inout WorkspaceInstallation) throws -> Void
    ) throws -> WorkspaceRegistration {
        var installation = WorkspaceInstallation()
        try body(
            &installation
        )

        guard !installation.operations.isEmpty else {
            throw WorkspaceError.empty_installation
        }

        let candidateRevision = try revision.advanced()
        let registrationIdentifier = WorkspaceRegistrationIdentifier()
        var candidatePaths = paths
        var candidateGrants = grantRecords
        var candidateRegistrations = registrationRecords
        var installedRoots: [PathAccessRootIdentifier] = []
        var installedGrants: [WorkspaceGrantIdentifier] = []

        for operation in installation.operations {
            switch operation {
            case .root(let root):
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

            case .grant(let grant):
                guard candidateGrants[grant.id] == nil else {
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

                candidateGrants[grant.id] = WorkspaceGrantRecord(
                    grant: grant,
                    state: .active
                )
                installedGrants.append(
                    grant.id
                )
            }
        }

        let registration = WorkspaceRegistration(
            id: registrationIdentifier,
            roots: installedRoots,
            grants: installedGrants,
            revision: candidateRevision
        )
        candidateRegistrations[registrationIdentifier] = WorkspaceRegistrationRecord(
            registration: registration,
            state: .active
        )

        try Self.requireConsistency(
            paths: candidatePaths,
            grants: candidateGrants,
            registrations: candidateRegistrations
        )

        paths = candidatePaths
        grantRecords = candidateGrants
        registrationRecords = candidateRegistrations
        revision = candidateRevision

        return registration
    }

    @discardableResult
    mutating func replace(
        _ grant: WorkspaceGrant
    ) throws -> WorkspaceRevision {
        try update { update in
            update.replace(
                grant
            )
        }
    }

    @discardableResult
    mutating func invalidate(
        _ identifier: WorkspaceGrantIdentifier
    ) throws -> WorkspaceRevision {
        try update { update in
            update.invalidate(
                identifier
            )
        }
    }

    @discardableResult
    mutating func removeRoot(
        _ identifier: PathAccessRootIdentifier
    ) throws -> WorkspaceRevision {
        try update { update in
            update.removeRoot(
                identifier
            )
        }
    }

    @discardableResult
    mutating func update(
        _ body: (inout WorkspaceUpdate) throws -> Void
    ) throws -> WorkspaceRevision {
        var update = WorkspaceUpdate()
        try body(
            &update
        )

        guard !update.operations.isEmpty else {
            return revision
        }

        let candidateRevision = try revision.advanced()
        var candidatePaths = paths
        var candidateGrants = grantRecords
        let candidateRegistrations = registrationRecords
        var changed = false

        for operation in update.operations {
            switch operation {
            case .replace_grant(let grant):
                guard candidateGrants[grant.id] != nil else {
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

                candidateGrants[grant.id] = WorkspaceGrantRecord(
                    grant: grant,
                    state: .active
                )
                changed = true

            case .invalidate_grant(let identifier):
                guard let existing = candidateGrants[identifier] else {
                    throw WorkspaceError.grant_not_found(
                        identifier
                    )
                }

                guard case .active = existing.state else {
                    continue
                }

                candidateGrants[identifier] = WorkspaceGrantRecord(
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

                try Self.requireRootRemovable(
                    identifier,
                    grants: candidateGrants,
                    registrations: candidateRegistrations
                )
                candidatePaths = candidatePaths.removingRoot(
                    identifier: identifier
                )
                changed = true
            }
        }

        guard changed else {
            return revision
        }

        candidatePaths = Self.reclaimInactiveRegistrationRoots(
            paths: candidatePaths,
            grants: candidateGrants,
            registrations: candidateRegistrations
        )

        try Self.requireConsistency(
            paths: candidatePaths,
            grants: candidateGrants,
            registrations: candidateRegistrations
        )

        paths = candidatePaths
        grantRecords = candidateGrants
        revision = candidateRevision

        return candidateRevision
    }

    @discardableResult
    mutating func invalidate(
        _ registration: WorkspaceRegistration
    ) throws -> WorkspaceRevision {
        try invalidate(
            registration.id
        )
    }

    @discardableResult
    mutating func invalidate(
        _ identifier: WorkspaceRegistrationIdentifier
    ) throws -> WorkspaceRevision {
        guard let existing = registrationRecords[identifier] else {
            throw WorkspaceError.registration_not_found(
                identifier
            )
        }
        guard case .active = existing.state else {
            throw WorkspaceError.registration_not_active(
                identifier
            )
        }

        let candidateRevision = try revision.advanced()
        var candidatePaths = paths
        var candidateGrants = grantRecords
        var candidateRegistrations = registrationRecords

        for grantIdentifier in existing.registration.grants {
            guard let grantRecord = candidateGrants[grantIdentifier],
                  case .active = grantRecord.state
            else {
                continue
            }

            candidateGrants[grantIdentifier] = WorkspaceGrantRecord(
                grant: grantRecord.grant,
                state: .invalidated(
                    candidateRevision
                )
            )
        }

        candidateRegistrations[identifier] = WorkspaceRegistrationRecord(
            registration: existing.registration,
            state: .invalidated(
                candidateRevision
            )
        )

        candidatePaths = Self.reclaimInactiveRegistrationRoots(
            paths: candidatePaths,
            grants: candidateGrants,
            registrations: candidateRegistrations
        )

        try Self.requireConsistency(
            paths: candidatePaths,
            grants: candidateGrants,
            registrations: candidateRegistrations
        )

        paths = candidatePaths
        grantRecords = candidateGrants
        registrationRecords = candidateRegistrations
        revision = candidateRevision

        return candidateRevision
    }

    @discardableResult
    mutating func revalidate(
        at date: Date = Date()
    ) throws -> WorkspaceRevision {
        let expiring = grantRecords.values.filter { record in
            guard case .active = record.state,
                  let expiresAt = record.grant.expiresAt
            else {
                return false
            }

            return date >= expiresAt
        }

        guard !expiring.isEmpty else {
            return revision
        }

        let candidateRevision = try revision.advanced()
        var candidatePaths = paths
        var candidateGrants = grantRecords

        for record in expiring {
            guard let expiresAt = record.grant.expiresAt else {
                continue
            }

            candidateGrants[record.grant.id] = WorkspaceGrantRecord(
                grant: record.grant,
                state: .expired(
                    at: expiresAt,
                    revision: candidateRevision
                )
            )
        }

        candidatePaths = Self.reclaimInactiveRegistrationRoots(
            paths: candidatePaths,
            grants: candidateGrants,
            registrations: registrationRecords
        )

        try Self.requireConsistency(
            paths: candidatePaths,
            grants: candidateGrants,
            registrations: registrationRecords
        )

        paths = candidatePaths
        grantRecords = candidateGrants
        revision = candidateRevision

        return candidateRevision
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
            sourceSnapshot: request.sourceSnapshot,
            at: date
        )
    }

    func authorize(
        rootIdentifier: PathAccessRootIdentifier? = nil,
        path: DescendantPath,
        capability: WorkspaceCapability,
        lineRange: LineRange? = nil,
        sourceSnapshot: FileReadSnapshot? = nil,
        at date: Date = Date()
    ) throws -> WorkspaceAuthorization {
        if lineRange != nil,
           !capability.supportsContentRange
        {
            throw WorkspaceError.invalid_line_range_capability(
                capability
            )
        }

        let authorizedPath = try paths.authorize(
            path,
            rootIdentifier: rootIdentifier
        )

        return try authorization(
            for: authorizedPath,
            capability: capability,
            lineRange: lineRange,
            sourceSnapshot: sourceSnapshot,
            at: date
        )
    }

    func requireCurrent(
        _ authorization: WorkspaceAuthorization,
        currentSourceSnapshot: FileReadSnapshot? = nil,
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
        let sourceSnapshot = try sourceSnapshotForReauthorization(
            authorization,
            currentSourceSnapshot: currentSourceSnapshot
        )

        guard let record = grantRecords[authorization.grantIdentifier],
              record.status(at: date) == .active,
              record.grant.capabilities.contains(
                authorization.capability
              ),
              record.grant.rootIdentifier == currentPath.rootIdentifier,
              record.grant.scope.matches(
                currentPath.path,
                lineRange: authorization.lineRange
              )
        else {
            throw WorkspaceError.authorization_denied(
                root: currentPath.rootIdentifier,
                path: currentPath.presentationPath,
                capability: authorization.capability
            )
        }

        try Self.requireSourceSnapshot(
            scope: record.grant.scope,
            supplied: sourceSnapshot,
            authorizedPath: currentPath
        )
    }

    func reauthorize(
        _ authorization: WorkspaceAuthorization,
        currentSourceSnapshot: FileReadSnapshot? = nil,
        at date: Date = Date()
    ) throws -> WorkspaceAuthorization {
        let currentPath = try paths.authorize(
            authorization.authorizedPath.path,
            rootIdentifier: authorization.authorizedPath.rootIdentifier
        )
        let sourceSnapshot = try sourceSnapshotForReauthorization(
            authorization,
            currentSourceSnapshot: currentSourceSnapshot
        )

        return try self.authorization(
            for: currentPath,
            capability: authorization.capability,
            lineRange: authorization.lineRange,
            sourceSnapshot: sourceSnapshot,
            at: date
        )
    }
}

private extension Workspace {
    func sourceSnapshotForReauthorization(
        _ authorization: WorkspaceAuthorization,
        currentSourceSnapshot: FileReadSnapshot?
    ) throws -> FileReadSnapshot? {
        guard authorization.sourceSnapshot != nil else {
            return currentSourceSnapshot
        }
        guard let currentSourceSnapshot else {
            throw WorkspaceError.source_snapshot_required(
                authorization.authorizedPath.presentationPath
            )
        }

        return currentSourceSnapshot
    }

    func authorization(
        for authorizedPath: AuthorizedPath,
        capability: WorkspaceCapability,
        lineRange: LineRange?,
        sourceSnapshot: FileReadSnapshot?,
        at date: Date
    ) throws -> WorkspaceAuthorization {
        var requiresSnapshot = false
        var staleSnapshot = false

        let candidates = grantRecords.values
            .filter { record in
                record.status(at: date) == .active
                    && record.grant.rootIdentifier == authorizedPath.rootIdentifier
                    && record.grant.capabilities.contains(capability)
                    && record.grant.scope.matches(
                        authorizedPath.path,
                        lineRange: lineRange
                    )
            }
            .sorted {
                $0.grant.id.rawValue < $1.grant.id.rawValue
            }

        for record in candidates {
            if let expected = record.grant.scope.sourceSnapshot {
                guard let sourceSnapshot else {
                    requiresSnapshot = true
                    continue
                }

                guard expected == sourceSnapshot else {
                    staleSnapshot = true
                    continue
                }
            }

            return WorkspaceAuthorization(
                authorizedPath: authorizedPath,
                capability: capability,
                lineRange: lineRange,
                sourceSnapshot: sourceSnapshot,
                grantIdentifier: record.grant.id,
                revision: revision
            )
        }

        if staleSnapshot {
            throw WorkspaceError.stale_source_snapshot(
                authorizedPath.presentationPath
            )
        }
        if requiresSnapshot {
            throw WorkspaceError.source_snapshot_required(
                authorizedPath.presentationPath
            )
        }

        throw WorkspaceError.authorization_denied(
            root: authorizedPath.rootIdentifier,
            path: authorizedPath.presentationPath,
            capability: capability
        )
    }

    static func requireSourceSnapshot(
        scope: WorkspaceScope,
        supplied: FileReadSnapshot?,
        authorizedPath: AuthorizedPath
    ) throws {
        guard let expected = scope.sourceSnapshot else {
            return
        }
        guard let supplied else {
            throw WorkspaceError.source_snapshot_required(
                authorizedPath.presentationPath
            )
        }
        guard expected == supplied else {
            throw WorkspaceError.stale_source_snapshot(
                authorizedPath.presentationPath
            )
        }
    }

    static func requireRootRemovable(
        _ identifier: PathAccessRootIdentifier,
        grants: [WorkspaceGrantIdentifier: WorkspaceGrantRecord],
        registrations: [WorkspaceRegistrationIdentifier: WorkspaceRegistrationRecord]
    ) throws {
        let activeGrants = grants.values.compactMap { record -> WorkspaceGrantIdentifier? in
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

        guard activeGrants.isEmpty else {
            throw WorkspaceError.root_has_active_grants(
                root: identifier,
                grants: activeGrants
            )
        }

        let activeRegistrations = registrations.values.compactMap { record -> WorkspaceRegistrationIdentifier? in
            guard case .active = record.state,
                  record.registration.roots.contains(identifier)
            else {
                return nil
            }

            return record.registration.id
        }
        .sorted {
            $0.description < $1.description
        }

        guard activeRegistrations.isEmpty else {
            throw WorkspaceError.root_has_active_registrations(
                root: identifier,
                registrations: activeRegistrations
            )
        }
    }

    static func reclaimInactiveRegistrationRoots(
        paths: PathAccessController,
        grants: [WorkspaceGrantIdentifier: WorkspaceGrantRecord],
        registrations: [WorkspaceRegistrationIdentifier: WorkspaceRegistrationRecord]
    ) -> PathAccessController {
        var paths = paths
        let registrationOwnedRoots = Set(
            registrations.values.flatMap {
                $0.registration.roots
            }
        )

        for identifier in registrationOwnedRoots {
            guard paths.roots[identifier] != nil else {
                continue
            }

            let hasActiveGrant = grants.values.contains { record in
                guard case .active = record.state else {
                    return false
                }

                return record.grant.rootIdentifier == identifier
            }
            let hasActiveRegistration = registrations.values.contains { record in
                guard case .active = record.state else {
                    return false
                }

                return record.registration.roots.contains(
                    identifier
                )
            }

            if !hasActiveGrant,
               !hasActiveRegistration
            {
                paths = paths.removingRoot(
                    identifier: identifier
                )
            }
        }

        return paths
    }

    static func requireSourceBinding(
        for grant: WorkspaceGrant,
        paths: PathAccessController
    ) throws {
        guard let sourceSnapshot = grant.scope.sourceSnapshot,
              let contentLineRange = grant.scope.contentLineRange
        else {
            return
        }

        let sourcePath: AuthorizedPath

        do {
            sourcePath = try paths.authorize(
                sourceSnapshot.url,
                rootIdentifier: grant.rootIdentifier,
                type: .file
            )
        } catch {
            throw WorkspaceError.source_snapshot_path_mismatch(
                grant: grant.id
            )
        }

        guard grant.scope.matches(
            sourcePath.path,
            lineRange: contentLineRange
        ) else {
            throw WorkspaceError.source_snapshot_path_mismatch(
                grant: grant.id
            )
        }
    }

    static func requireConsistency(
        paths: PathAccessController,
        grants: [WorkspaceGrantIdentifier: WorkspaceGrantRecord],
        registrations: [WorkspaceRegistrationIdentifier: WorkspaceRegistrationRecord]
    ) throws {
        for (identifier, record) in grants {
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

            try requireSourceBinding(
                for: record.grant,
                paths: paths
            )
        }

        for record in registrations.values {
            guard case .active = record.state else {
                continue
            }

            for identifier in record.registration.roots {
                guard paths.roots[identifier] != nil else {
                    throw WorkspaceError.root_not_found(
                        identifier
                    )
                }
            }
        }
    }
}
