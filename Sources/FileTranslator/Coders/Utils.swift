// Created 1/13/23
// swift-version:5.0

import Foundation

/// ``StringEnumCodingKey`` is used to support decoding an object (typically coded with a dictionary) using a zero-indexed array of `Any` value.
protocol StringEnumCodingKey : CodingKey, CaseIterable, RawRepresentable where RawValue == String {
}

extension StringEnumCodingKey {
    static func allValues() -> [String] {
        return self.allCases.map { $0.rawValue }
    }

    var intValue: Int? {
        type(of: self).allValues().firstIndex(of: self.rawValue)
    }
    
    init?(intValue: Int) {
        let values = Self.allValues()
        guard intValue < values.count else { return nil }
        self.init(rawValue: values[intValue])
    }
}
