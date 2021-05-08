//// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import Nuke

class ImagePipelineLoadDataTests: XCTestCase {
    var dataLoader: MockDataLoader!
    var dataCache: MockDataCache!
    var pipeline: ImagePipeline!
    var encoder: MockImageEncoder!

    override func setUp() {
        super.setUp()

        dataLoader = MockDataLoader()
        dataCache = MockDataCache()
        encoder = MockImageEncoder(result: Test.data)
        pipeline = ImagePipeline {
            $0.dataLoader = dataLoader
            $0.dataCache = dataCache
            $0.imageCache = nil
            $0.makeImageEncoder = { [unowned self] _ in self.encoder }
            $0.debugIsSyncImageEncoding = true
        }
    }

    func testLoadDataDataLoaded() {
        let expectation = self.expectation(description: "Image data Loaded")
        pipeline.loadData(with: Test.request) { result in
            let response = try! XCTUnwrap(result.value)
            XCTAssertEqual(response.data.count, 22789)
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        }
        wait()
    }

    // MARK: - Progress Reporting

    func testProgressClosureIsCalled() {
        // Given
        let request = ImageRequest(url: Test.url)

        dataLoader.results[Test.url] = .success(
            (Data(count: 20), URLResponse(url: Test.url, mimeType: "jpeg", expectedContentLength: 20, textEncodingName: nil))
        )

        // When
        let expectedProgress = expectProgress([(10, 20), (20, 20)])

        pipeline.loadData(
            with: request,
            progress: { completed, total in
                // Then
                XCTAssertTrue(Thread.isMainThread)
                expectedProgress.received((completed, total))
            },
            completion: { _ in }
        )

        wait()
    }

    func testProgressObjectIsUpdated() {
        // Given
        let request = Test.request

        dataLoader.results[Test.url] = .success(
            (Data(count: 20), URLResponse(url: Test.url, mimeType: "jpeg", expectedContentLength: 20, textEncodingName: nil))
        )

        // When
        let expectTaskFinished = self.expectation(description: "Task finished")
        let task = pipeline.loadData(with: request) { _ in
            expectTaskFinished.fulfill()
        }

        // Then
        self.expect(values: [20], for: task.progress, keyPath: \.totalUnitCount) { _, _ in
            XCTAssertTrue(Thread.isMainThread)
        }
        self.expect(values: [10, 20], for: task.progress, keyPath: \.completedUnitCount) { _, _ in
            XCTAssertTrue(Thread.isMainThread)
        }

        wait()
    }

    func testTaskProgressIsUpdated() {
        // Given
        let request = ImageRequest(url: Test.url)

        dataLoader.results[Test.url] = .success(
            (Data(count: 20), URLResponse(url: Test.url, mimeType: "jpeg", expectedContentLength: 20, textEncodingName: nil))
        )

        // When
        let expectedProgress = expectProgress([(10, 20), (20, 20)])

        var task: ImageTask!
        task = pipeline.loadData(
            with: request,
            progress: { completed, total in
                // Then
                XCTAssertTrue(Thread.isMainThread)
                expectedProgress.received((task.completedUnitCount, task.totalUnitCount))
            },
            completion: { _ in }
        )

        wait()
    }

    // MARK: Cache Lookup

    func testCacheLookupReturnedFromCacheWhenOriginalDataStored() {

    }

    #warning("todo")
    func testCacheLookupReturedFromCacheWhenProcessedImageDataStored() {

    }

    #warning("todo")
    func _testCacheLookupReturnsEncodedImageWhenOriginalImageDataStored() {

    }

    // MARK: DiskCachPolicy.automatic

    #warning("todo")
    func _testPolicyAutomaticGivenRequestWithProcessors() {
        // GIVEN
        pipeline = pipeline.reconfigured {
            $0.dataCachePolicy = .automatic
        }

        // GIVEN request with a processor
        let request = ImageRequest(url: Test.url, processors: [MockImageProcessor(id: "p1")])

        // WHEN
        expect(pipeline).toLoadData(with: request)
        wait()

        // THEN encoded processed image is stored in disk cache
        XCTAssertEqual(encoder.encodeCount, 1)
        XCTAssertNotNil(dataCache.cachedData(for: Test.url.absoluteString + "p1"))
        XCTAssertEqual(dataCache.writeCount, 1)
        XCTAssertEqual(dataCache.store.count, 1)
    }

    func testPolicyAutomaticGivenRequestWithoutProcessors() {
        // GIVEN
        pipeline = pipeline.reconfigured {
            $0.dataCachePolicy = .automatic
        }

        // GIVEN request without a processor
        let request = ImageRequest(url: Test.url)

        // WHEN
        expect(pipeline).toLoadData(with: request)
        wait()

        // THEN original image data is stored in disk cache
        XCTAssertEqual(encoder.encodeCount, 0)
        XCTAssertNotNil(dataCache.cachedData(for: Test.url.absoluteString))
        XCTAssertEqual(dataCache.writeCount, 1)
        XCTAssertEqual(dataCache.store.count, 1)
    }

    #warning("todo")
    func _testPolicyAutomaticGivenTwoRequests() {
        // GIVEN
        pipeline = pipeline.reconfigured {
            $0.dataCachePolicy = .automatic
        }

        // WHEN
        expect(pipeline).toLoadImage(with: ImageRequest(url: Test.url, processors: [MockImageProcessor(id: "p1")]))
        expect(pipeline).toLoadImage(with: ImageRequest(url: Test.url))
        wait()

        // THEN
        // encoded processed image is stored in disk cache
        // original image data is stored in disk cache
        XCTAssertEqual(encoder.encodeCount, 1)
        XCTAssertNotNil(dataCache.cachedData(for: Test.url.absoluteString + "p1"))
        XCTAssertNotNil(dataCache.cachedData(for: Test.url.absoluteString))
        XCTAssertEqual(dataCache.writeCount, 2)
        XCTAssertEqual(dataCache.store.count, 2)
    }

    // MARK: - Callback Queues

    func testChangingCallbackQueueLoadData() {
        // Given
        let queue = DispatchQueue(label: "testChangingCallbackQueue")
        let queueKey = DispatchSpecificKey<Void>()
        queue.setSpecific(key: queueKey, value: ())

        // When/Then
        let expectation = self.expectation(description: "Image data Loaded")
        pipeline.loadData(with: Test.request,queue: queue, progress: { _, _ in
            XCTAssertNotNil(DispatchQueue.getSpecific(key: queueKey))
        }, completion: { _ in
            XCTAssertNotNil(DispatchQueue.getSpecific(key: queueKey))
            expectation.fulfill()
        })
        wait()
    }
}
