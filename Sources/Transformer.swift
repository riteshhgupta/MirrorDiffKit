import Foundation



func transform(fromAny x: Any?) -> Diffable {
    switch x {
    case .none:
        return .none
    case let .some(y):
        return transformFromNonOptionalAny(y)
    }
}


private func transformFromNonOptionalAny(_ x: Any) -> Diffable {
    if let y = x as? NSNull {
        return Diffable.from(y)
    }

    // MARK: - Integer subtypes
    if let y = x as? Int {
        return Diffable.from(y)
    }

    if let y = x as? Int8 {
        return Diffable.from(y)
    }

    if let y = x as? Int16 {
        return Diffable.from(y)
    }

    if let y = x as? Int32 {
        return Diffable.from(y)
    }

    if let y = x as? Int64 {
        return Diffable.from(y)
    }

    if let y = x as? UInt {
        return Diffable.from(y)
    }

    if let y = x as? UInt8 {
        return Diffable.from(y)
    }

    if let y = x as? UInt16 {
        return Diffable.from(y)
    }

    if let y = x as? UInt32 {
        return Diffable.from(y)
    }

    if let y = x as? UInt64 {
        return Diffable.from(y)
    }


    // MARK: - FloatingPoint subtypes
    if let y = x as? Double {
        return Diffable.from(y)
    }

    if let y = x as? Float {
        return Diffable.from(y)
    }

    if let y = x as? Float32 {
        return Diffable.from(y)
    }

    if let y = x as? Float64 {
        return Diffable.from(y)
    }

    #if arch(x86_64) || arch(i386)
        if let y = x as? Float80 {
            return Diffable.from(y)
        }
    #endif


    // MARK: - String related types
    if let y = x as? Character {
        return Diffable.from(y)
    }

    if let y = x as? String {
        return Diffable.from(y)
    }


    // MARK: - Bool subtypes
    if let y = x as? Bool {
        return Diffable.from(y)
    }


    if let y = x as? Date {
        return Diffable.from(y)
    }


    if let y = x as? URL {
        return Diffable.from(y)
    }


    // XXX: Avoid the following error (at least, Swift 3.0.2 or earlier):
    //
    // > Protocol "SpecialController" can only be used as a generic constraint
    // > because it has Self or associated type requirements.
    //
    // So, we can only try to cast concrete collection types. See all concrete
    // types in SDK: http://swiftdoc.org/v3.0/protocol/Collection/hierarchy/
    if let y = x as? [Any] {
        return Diffable.from(y)
    }

    return transformMirror(of: x)
}



func transformMirror(of x: Any) -> Diffable {
    do {
        let mirror = Mirror(reflecting: x)

        switch mirror.displayStyle {
            // XXX: Handle `nil` in a variable typed Any here.
            //
            // (lldb) po let $var: Any? = nil
            // (lldb) po let $container: Any = $var
            // (lldb) po $container == nil
            // false <- FUUUUUUUUUUUUU
            //
            // (lldb) po Mirror(reflecting: $container)
            // Mirror for Optional<Any>
            //
            // Therefore we can handle it by only using Mirrors.
        case .some(.optional):
            return .none

        case .some(.tuple):
            let entries = try transformFromLabeledMirror(of: mirror)
            return .tuple(entries)

        case .some(.set):
            let entries = transformFromNonLabeldMirror(of: mirror)
            return .set(entries)

        case .some(.enum):
            let associated = transformFromTupleMirror(of: mirror)

            return .anyEnum(
                type: mirror.subjectType,
                value: x,
                associated: associated
            )

        case .some(.struct):
            let entries = try transformFromLabeledMirror(of: mirror)
            return .anyStruct(type: mirror.subjectType, entries: entries)

        case .some(.class):
            let entries = try transformFromLabeledMirror(of: mirror)
            return .anyClass(type: mirror.subjectType, entries: entries)

        case .none:
            // XXX: I don't know why but Generic structs and classes do not have .displayStyle.
            let entries = try transformFromLabeledMirror(of: mirror)
            return .generic(type: mirror.subjectType, entries: entries)

        default:
            return .notSupported(value: x)
        }
    }
    catch {
        return .unrecognizable(debugInfo: "error=`\(error)`, value=`\(x)`")
    }
}



private func transformFromLabeledMirror(of mirror: Mirror) throws -> [String: Diffable] {
    var dictionary = [String: Diffable]()

    try mirror.children.forEach { (label, value) throws in
        guard let label = label else {
            let debugInfo = String(describing: ["entryValue": value])
            throw TransformError.unexpectedNilLabel(debugInfo: debugInfo)
        }
        dictionary[label] = transform(fromAny: value)
    }

    return dictionary
}



private func transformFromNonLabeldMirror(of mirror: Mirror) -> [Diffable] {
    return mirror.children.map { (_, value) in transform(fromAny: value) }
}


private func transformFromTupleMirror(of mirror: Mirror) -> [Diffable] {
    // NOTE: Tuple's children of mirror do not have consistent representations:
    //
    //   - void tuple's children = [T] (empty)
    //   - unary tuple's children = T
    //   - N-ary tuple's children = [T]

    guard let firstChild = mirror.children.first else {
        // It is a void tuple.
        return []
    }

    let childMirror = Mirror(reflecting: firstChild.value)

    guard childMirror.displayStyle == .tuple else {
        // It is an unary tuple.
        return [transform(fromAny: firstChild.value)]
    }

    // It is a N-ary tuple. (N >= 2)
    return childMirror.children
        .map { transform(fromAny: $0.value) }
}



enum TransformError: Error {
    case unexpectedNilLabel(debugInfo: String)
    case unexpectedMirrorStructureForAssociatedTuple(debugInfo: String)
}


extension TransformError: Equatable {
    static func == (_ lhs: TransformError, _ rhs: TransformError) -> Bool {
        switch (lhs, rhs) {
        case (.unexpectedNilLabel, .unexpectedNilLabel):
            return true
        case (.unexpectedMirrorStructureForAssociatedTuple, .unexpectedMirrorStructureForAssociatedTuple):
            return true
        default:
            return false
        }
    }
}
