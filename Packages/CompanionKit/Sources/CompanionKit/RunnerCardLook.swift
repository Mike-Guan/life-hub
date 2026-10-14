import HubCore

/// The outfit HAKU wears on the fourth slot for an identity card.
enum CardLook: Sendable, Equatable, CaseIterable {
    /// Gloves, headband and the boxing face.
    case boxing
    /// The dark jacket with an orange stripe and a wristband.
    case sport
    /// The green off-work jacket.
    case outing
    /// The green jacket with an apron.
    case making

    /// The look for `kind`.
    init(_ kind: IdentityKind) {
        switch kind {
        case .boxing: self = .boxing
        case .tennis, .fitness, .swimming, .yoga, .dance, .ball, .ski: self = .sport
        case .outdoor: self = .outing
        case .music, .art, .study: self = .making
        }
    }
}
