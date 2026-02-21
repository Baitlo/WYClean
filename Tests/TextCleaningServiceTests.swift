import XCTest
@testable import WYClean

final class TextCleaningServiceTests: XCTestCase {
    private let service = TextCleaningService()

    func testOCRBrokenLineAndRandomSpaces() {
        let input = "这 是 一段\nOCR 识别\r\n后 的 文本\t，  存在   多余空格。"
        let output = service.clean(input)
        XCTAssertEqual(output, "这是一段 OCR识别后的文本，存在多余空格。")
    }

    func testMixedChineseEnglishSpacing() {
        let input = "我 是 AI engineer ， 主要 处理 NLP tasks ."
        let output = service.clean(input)
        XCTAssertEqual(output, "我是 AI engineer，主要处理 NLP tasks .")
    }

    func testCitationsInMultipleFormats() {
        let input = "根据研究[1]，该方法优于基线[4-7]，效果显著(2, 3)。"
        let output = service.clean(input)
        XCTAssertEqual(output, "根据研究，该方法优于基线，效果显著。")
    }

    func testMixedFullWidthAndHalfWidth() {
        let input = "ＡI模型在２０２４年表现优异, accuracy 达到９９% ."
        let output = service.clean(input)
        XCTAssertEqual(output, "AI模型在2024年表现优异，accuracy 达到99% .")
    }

    func testRuleOrderProducesStableResult() {
        let input = "测 试[12]\nＡI, 模型(2, 3)\t结 果."
        let output = service.clean(input)
        XCTAssertEqual(output, "测试 AI，模型结果。")
    }
}
