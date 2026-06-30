import XCTest
@testable import ReceiptFax

final class KeychainStoreTests: XCTestCase {
    let key = "test.keychain.\(UUID().uuidString)"

    override func tearDown() {
        KeychainStore.delete(key)
    }

    func testSaveAndLoad() throws {
        try KeychainStore.save("secret", for: key)
        XCTAssertEqual(KeychainStore.load(key), "secret")
    }

    func testOverwriteValue() throws {
        try KeychainStore.save("first", for: key)
        try KeychainStore.save("second", for: key)
        XCTAssertEqual(KeychainStore.load(key), "second")
    }

    func testLoadMissingReturnsNil() {
        XCTAssertNil(KeychainStore.load("nonexistent.\(UUID().uuidString)"))
    }

    func testDeleteRemovesValue() throws {
        try KeychainStore.save("value", for: key)
        KeychainStore.delete(key)
        XCTAssertNil(KeychainStore.load(key))
    }

    func testDeleteNonexistentIsSafe() {
        KeychainStore.delete("nonexistent.\(UUID().uuidString)")
    }
}
