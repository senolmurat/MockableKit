import XCTest
@testable import MockableKit

struct SimpleStruct: Decodable, Mockable {
    let name: String
    let age: Int
}

struct NestedStruct: Decodable, Mockable {
    let id: Int
    let user: SimpleStruct
}

struct ComplexStruct: Decodable, Mockable {
    let name: String
    let nested: NestedStruct
    let items: [SimpleStruct]
    let nestedList: [NestedStruct]
}

final class SchemaExtractorTests: XCTestCase {
    
    func testSimpleStructExtraction() {
        let fields = SchemaExtractor.extract(from: SimpleStruct.self)
        XCTAssertEqual(fields.count, 2)
        XCTAssertTrue(fields.contains(where: { $0.name == "name" && $0.typeName == "String" }))
        XCTAssertTrue(fields.contains(where: { $0.name == "age" && $0.typeName == "Int" }))
    }
    
    func testNestedStructExtraction() {
        let fields = SchemaExtractor.extract(from: NestedStruct.self)
        XCTAssertEqual(fields.count, 2)
        XCTAssertTrue(fields.contains(where: { $0.name == "id" && $0.typeName == "Int" }))
        
        // This should also include the nested user field with its fields
        let userField = fields.first { $0.name == "user" }
        XCTAssertNotNil(userField)
        XCTAssertEqual(userField?.typeName, "SimpleStruct")
        // The nested fields should be extracted here
        XCTAssertFalse(userField?.nestedFields.isEmpty ?? true)
        XCTAssertTrue(userField?.nestedFields.contains(where: { $0.name == "age" && $0.typeName == "Int" }) ?? false)
        XCTAssertTrue(userField?.nestedFields.contains(where: { $0.name == "name" && $0.typeName == "String" }) ?? false)
    }
    
    func testComplexStructExtraction() {
        let fields = SchemaExtractor.extract(from: ComplexStruct.self)
        XCTAssertEqual(fields.count, 4)
        XCTAssertTrue(fields.contains(where: { $0.name == "name" && $0.typeName == "String" }))
        
        // Check nested field
        let nestedField = fields.first { $0.name == "nested" }
        XCTAssertNotNil(nestedField)
        XCTAssertEqual(nestedField?.typeName, "NestedStruct")
        XCTAssertTrue(nestedField?.nestedFields.contains(where: { $0.name == "id" && $0.typeName == "Int" }) ?? false)
        
        // Check array field
        let itemsField = fields.first { $0.name == "items" }
        XCTAssertNotNil(itemsField)
        XCTAssertEqual(itemsField?.typeName, "[SimpleStruct]")
        
        // Check array nested field
        let nestedItemsField = fields.first { $0.name == "nestedList" }
        XCTAssertNotNil(nestedItemsField)
        XCTAssertEqual(nestedItemsField?.typeName, "[NestedStruct]")
    }
}
