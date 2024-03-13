import Foundation

public extension Encodable {
    func toJSONData(jsonEncoder: JSONEncoder = JSONEncoder()) throws -> Data { try jsonEncoder
        .encode(self)
    }

    func toJSON<Key>(jsonEncoder: JSONEncoder = JSONEncoder()) throws -> [Key: Any] {
        let data = try jsonEncoder.encode(self)
        let jsonAny = try JSONSerialization.jsonObject(with: data, options: [])

        guard let json = jsonAny as? [Key: Any] else {
            throw NSError(
                domain: "Json object is not [AnyHashable : Any] type",
                code: 1,
                userInfo: nil
            )
        }

        return json
    }

    func asDictionary(jsonEncoder: JSONEncoder = JSONEncoder()) throws -> [String: Any] {
        let result: [String: Any]?
        do {
            result = try JSONSerialization
                .jsonObject(with: jsonEncoder.encode(self)) as? [String: Any]
        }
        catch {
            result = .none
        }
        assert(result != nil)
        return result ?? [:]
    }

    func asDictionaryEncodable() throws -> [AnyHashable: Encodable] {
        let result: [AnyHashable: Encodable]?
        do {
            result = try JSONSerialization
                .jsonObject(with: JSONEncoder().encode(self)) as? [AnyHashable: Encodable]
        }
        catch {
            result = .none
        }
        assert(result != nil)
        return result ?? [:]
    }
}

extension Decodable {
    public static func create(from data: Data) throws -> Self {
        let model = try JSONDecoder().decode(self, from: data)
        return model
    }

    public static func create(from json: [AnyHashable: Any]) throws -> Self {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        return try self.create(from: data)
    }
}
