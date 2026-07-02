import XCTest
import UIKit
@testable import ReceiptFax

final class RichTextEditorTests: XCTestCase {

    func testRoundTripSingleLineMixedBold() {
        let lines = [RichLine(size: "normal", align: "left", spans: [
            RichSpan(text: "Hello ", bold: false),
            RichSpan(text: "world", bold: true)
        ])]
        let attrStr = richLinesToAttrString(lines)
        let result = attrStringToRichLines(attrStr)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].size, "normal")
        XCTAssertEqual(result[0].align, "left")
        XCTAssertEqual(result[0].spans.count, 2)
        XCTAssertEqual(result[0].spans[0].text, "Hello ")
        XCTAssertFalse(result[0].spans[0].bold)
        XCTAssertEqual(result[0].spans[1].text, "world")
        XCTAssertTrue(result[0].spans[1].bold)
    }

    func testRoundTripTwoLines() {
        let lines = [
            RichLine(size: "header", align: "center", spans: [RichSpan(text: "Title", bold: false)]),
            RichLine(size: "normal", align: "left", spans: [RichSpan(text: "Body", bold: false)])
        ]
        let result = attrStringToRichLines(richLinesToAttrString(lines))
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].size, "header")
        XCTAssertEqual(result[0].align, "center")
        XCTAssertEqual(result[1].size, "normal")
        XCTAssertEqual(result[1].align, "left")
    }

    func testEmptyStringGivesOneEmptyLine() {
        let result = attrStringToRichLines(NSAttributedString(string: ""))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].spans[0].text, "")
        XCTAssertFalse(result[0].spans[0].bold)
    }

    func testAdjacentSameBoldSpansMerged() {
        let font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let para = NSMutableParagraphStyle()
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: para, richSizeKey: "normal"]
        let attrStr = NSMutableAttributedString(string: "ab", attributes: attrs)
        attrStr.append(NSAttributedString(string: "cd", attributes: attrs))
        let result = attrStringToRichLines(attrStr)
        XCTAssertEqual(result[0].spans.count, 1)
        XCTAssertEqual(result[0].spans[0].text, "abcd")
    }

    func testSingleNewlineGivesTwoLines() {
        let lines = [
            RichLine(size: "normal", align: "left", spans: [RichSpan(text: "a", bold: false)]),
            RichLine(size: "normal", align: "left", spans: [RichSpan(text: "b", bold: false)])
        ]
        let result = attrStringToRichLines(richLinesToAttrString(lines))
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].spans[0].text, "a")
        XCTAssertEqual(result[1].spans[0].text, "b")
    }

    func testLargeSizePreserved() {
        let lines = [RichLine(size: "large", align: "center", spans: [RichSpan(text: "Big", bold: false)])]
        let result = attrStringToRichLines(richLinesToAttrString(lines))
        XCTAssertEqual(result[0].size, "large")
        XCTAssertEqual(result[0].align, "center")
    }

    func testBoldOnlyLinePreserved() {
        let lines = [RichLine(size: "normal", align: "left", spans: [RichSpan(text: "All bold", bold: true)])]
        let result = attrStringToRichLines(richLinesToAttrString(lines))
        XCTAssertTrue(result[0].spans[0].bold)
        XCTAssertEqual(result[0].spans[0].text, "All bold")
    }
}
