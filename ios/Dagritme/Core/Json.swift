import Foundation

enum Json {
    case text(String)
    case number(Double)
    case bool(Bool)
    case array([Json])
    case object([String: Json])
    case null

    init(_ raw: Any?) {
        guard let raw else { self = .null; return }
        switch raw {
        case let value as Json:
            self = value
        case let value as String:
            self = .text(value)
        case let value as NSNumber:
            self = CFGetTypeID(value) == CFBooleanGetTypeID()
                ? .bool(value.boolValue) : .number(value.doubleValue)
        case let value as [Any]:
            self = .array(value.map { Json($0) })
        case let value as [String: Any]:
            self = .object(value.mapValues { Json($0) })
        default:
            self = .null
        }
    }

    static func parse(_ data: Data) -> Json {
        guard let thing = try? JSONSerialization.jsonObject(
            with: data, options: [.fragmentsAllowed]) else { return .null }
        return Json(thing)
    }

    subscript(key: String) -> Json {
        if case let .object(object) = self { return object[key] ?? .null }
        return .null
    }

    var text: String {
        if case let .text(value) = self {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    func text(_ fallback: String) -> String {
        let value = text
        return value.isEmpty ? fallback : value
    }

    var number: Double? {
        switch self {
        case let .number(value): return value
        case let .text(value): return Double(value.trimmingCharacters(in: .whitespaces))
        default: return nil
        }
    }

    var flag: Bool {
        switch self {
        case let .bool(value): return value
        case let .number(value): return value != 0
        case let .text(value): return !value.isEmpty
        default: return false
        }
    }

    var array: [Json] {
        switch self {
        case let .array(values):
            return values.filter { !$0.isNone }
        case let .object(object):
            return object.keys
                .sorted { (Int($0) ?? .max, $0) < (Int($1) ?? .max, $1) }
                .compactMap { object[$0] }
                .filter { !$0.isNone }
        default:
            return []
        }
    }

    var keys: [String] {
        if case let .object(object) = self { return Array(object.keys) }
        return []
    }

    var isObject: Bool {
        if case .object = self { return true }
        return false
    }

    var isArray: Bool {
        if case .array = self { return true }
        return false
    }

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    var raw: Any? {
        switch self {
        case let .text(value): return value
        case let .number(value): return value
        case let .bool(value): return value
        case let .array(values): return values.map { $0.raw as Any }
        case let .object(object): return object.mapValues { $0.raw as Any }
        case .null: return nil
        }
    }
}
