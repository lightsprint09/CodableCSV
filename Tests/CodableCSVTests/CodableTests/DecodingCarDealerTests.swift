import XCTest
@testable import CodableCSV

/// Tests for the decodable school data tests.
final class DecodingCarDealerTests: XCTestCase {
    // List of all tests to run through SPM.
    static let allTests = [
        ("testCarDealerData", testCarDealerData),
        ("testCities", testCities),
        ("testWrapperContainers", testWrapperContainers)
    ]
    
    /// Test data used throughout this `XCTestCase`.
    private enum TestData {
        /// The column names for the CSV.
        static let header: [String] = ["sequence", "name", "doors", "retractibleRoof", "fuel"]
        /// List of pets available in the pet store.
        static let array: [[String]] = [
            ["0" , "Bolt"      , "2", "true" , "100"],
            ["1" , "Knockout"  , "3", "false", "10" ],
            ["2" , "Burner"    , "4", "false", "50" ],
            ["3" , "Pacer"     , "5", "true" , "330"],
            ["4" , "Blink"     , "2", "false", "222"],
            ["5" , "Scorch"    , "4", "true" , "177"],
            ["6" , "Furiosa"   , "2", "false", "532"],
            ["7" , "Hannibal"  , "5", "false", "29" ],
            ["8" , "Bam Bam"   , "5", "true" , "73" ],
            ["9" , "Snap"      , "3", "true" , "88" ],
            ["10", "Zinger"    , "2", "false", "43" ],
            ["11", "Screech"   , "4", "false", "278"],
            ["12", "Brimstone" , "5", "true" , "94" ],
            ["13", "Dust Devil", "5", "false", "64" ]
        ]
        /// Configuration used to generated the CSV data.
        static let configuration: DecoderConfiguration = .init(fieldDelimiter: .comma, rowDelimiter: .lineFeed, headerStrategy: .firstLine)
        /// String version of the test data.
        static let string: String = ([header] + array).toCSV(delimiters: configuration.delimiters)
        /// Data version of the test data.
        static let blob: Data = ([header] + array).toCSV(delimiters: configuration.delimiters)!
    }
    
    /// Tests the list of pets (without any Decodable functionality).
    func testCarDealerData() {
        let parsed: (headers: [String]?, rows: [[String]])
        do {
            parsed = try CSVReader.parse(string: TestData.string, configuration: TestData.configuration)
        } catch let error {
            return XCTFail("Unexpected error received:\n\(error)")
        }
        
        XCTAssertNotNil(parsed.headers)
        XCTAssertEqual(parsed.headers!, TestData.header)
        XCTAssertEqual(parsed.rows, TestData.array)
    }
}

extension DecodingCarDealerTests {
    /// Test unkeyed container and different usage of superDecoder and decoder.
    func testCities() {
        let decoder = CSVDecoder(configuration: TestData.configuration)
        
        let province: Province
        do {
            province = try decoder.decode(Province.self, from: TestData.blob, encoding: .utf8)
        } catch let error {
            return XCTFail("Unexpected error received:\n\(error)")
        }
        
        let cars = province.remainingCars + province.bigCity.cars + province.smallCity.cars
        XCTAssertEqual(TestData.array.count, cars.count)
        
        for (testCar, car) in zip(TestData.array, cars) {
            XCTAssertEqual(UInt(testCar[0])!, car.sequence)
            XCTAssertEqual(testCar[1], car.name)
            XCTAssertEqual(UInt8(testCar[2])!, car.doors)
            XCTAssertEqual(Int16(testCar[4]), car.fuel.value)
        }
    }
    
    private struct Province: Decodable {
        let bigCity: BigCity
        let smallCity: SmallCity
        var remainingCars: [Car] = []
        
        init(from decoder: Decoder) throws {
            var file = try decoder.unkeyedContainer()
            
            for _ in 0..<BigCity.startIndex {
                self.remainingCars.append(try file.decode(Car.self))
            }
            
            self.bigCity = try BigCity(from: try file.superDecoder())
            self.smallCity = try SmallCity(from: decoder)
        }
    }
    
    private struct BigCity: Decodable {
        private(set) var cars: [Car] = []
        static let startIndex = 5
        static let endIndex = 10
        
        init(from decoder: Decoder) throws {
            var file = try decoder.unkeyedContainer()
            
            for _ in BigCity.startIndex..<BigCity.endIndex {
                cars.append(try file.decode(Car.self))
            }
        }
    }
    
    private struct SmallCity: Decodable {
        private(set) var cars: [Car] = []
        static let startIndex = 10
        static let endIndex = 14
        
        init(from decoder: Decoder) throws {
            var file = try decoder.unkeyedContainer()
            
            for _ in SmallCity.startIndex..<SmallCity.endIndex {
                cars.append(try file.decode(Car.self))
            }
        }
    }
    
    fileprivate struct Car: Decodable {
        let sequence: UInt
        let name: String
        let doors: UInt8
        let retractibleRoof: Bool
        let fuel: Fuel
        
        struct Fuel: Decodable {
            let value: Int16
            
            init(from decoder: Decoder) throws {
                let field = try decoder.singleValueContainer()
                self.value = try field.decode(Int16.self)
            }
        }
    }
}

extension DecodingCarDealerTests {
    /// Tests the usage of wrapper containers.
    func testWrapperContainers() {
        let decoder = CSVDecoder(configuration: TestData.configuration)
        
        let topWrap: TopWrap
        do {
            topWrap = try decoder.decode(TopWrap.self, from: TestData.blob, encoding: .utf8)
        } catch let error {
            return XCTFail("Unexpected error received:\n\(error)")
        }
        
        let bottom = topWrap.middle.bottom
        XCTAssertEqual(bottom.count, TestData.array.count)
    }
    
    private struct TopWrap: Decodable {
        let middle: MiddleWrap
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.middle = try container.decode(MiddleWrap.self)
        }
    }
    
    private struct MiddleWrap: Decodable {
        private(set) var bottom: [BottomWrap] = []
        
        init(from decoder: Decoder) throws {
            var fileContainer = try decoder.unkeyedContainer()
            while !fileContainer.isAtEnd {
                bottom.append(try fileContainer.decode(BottomWrap.self))
            }
        }
    }
    
    private struct BottomWrap: Decodable {
        let sequence: UInt8
        let name: String
        
        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            self.sequence = try container.decode(UInt8.self)
            self.name = try container.decode(String.self)
        }
    }
}
