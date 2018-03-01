//
//  QueueTests.swift
//
//  Created by Kåre Morstøl on 11/07/14.
//  Copyright (c) 2014 NotTooBad Software. All rights reserved.
//

import XCTest
@testable import phyphox

final class QueueTests: XCTestCase {
    func testAdd1ToQueue() {
		let sut = Queue<String>()
		sut.enqueue("1")
    }

	func testAddSeveralToQueue() {
		let sut = Queue<String>()
		XCTAssert(sut.isEmpty)
		sut.enqueue("1")
		sut.enqueue("1")
		XCTAssertFalse(sut.isEmpty)
		sut.enqueue("1")
		sut.enqueue("1")
		sut.enqueue("1")
	}
	
	func testRemoveOne() {
		let sut = Queue<String>()
		sut.enqueue("1")
		sut.enqueue("")
		sut.enqueue("")
		sut.enqueue("")
		let thefirstone = sut.dequeue()
		
		XCTAssertNotNil(thefirstone)
		XCTAssertEqual(thefirstone!, "1")
	}
	
	func testRemoveAll() {
		let sut = Queue<String>()
		sut.enqueue("1")
		sut.enqueue("2")
		sut.enqueue("3")
		sut.enqueue("4")

		XCTAssertEqual(sut.dequeue()!, "1")
		XCTAssertEqual(sut.dequeue()!, "2")
		XCTAssertEqual(sut.dequeue()!, "3")
		XCTAssertEqual(sut.dequeue()!, "4")
		XCTAssert(sut.isEmpty)
		XCTAssertNil(sut.dequeue())
		XCTAssertNil(sut.dequeue())
		XCTAssert(sut.isEmpty)
	}
	
	func testGenerics() {
		let sut = Queue<Int>()
		sut.enqueue(1)
		sut.enqueue(2)
		sut.enqueue(3)
		sut.enqueue(4)
		
		XCTAssertEqual(sut.dequeue()!, 1)
		XCTAssertEqual(sut.dequeue()!, 2)
		XCTAssertEqual(sut.dequeue()!, 3)
		XCTAssertEqual(sut.dequeue()!, 4)
	}
    
    func testEnumeration() {
        let q = Queue<Int>()
        
        for i in 0...100 {
            q.enqueue(i)
        }
        
        var c = 0
        
        for i in q {
            XCTAssertEqual(c, i)
            c += 1
        }
        
        var iterator = q.makeIterator()
        
        c = 0
        
        while let i = iterator.next() {
            XCTAssertEqual(c, i)
            c += 1
        }
    }
    
    func testFirstLast() {
        let q = Queue<Int64>()
        
        q.enqueue(Int64.max)
        q.enqueue(0)
        q.enqueue(Int64.min)
        
        XCTAssertEqual(q.first, Int64.max)
        XCTAssertEqual(q.last, Int64.min)
        
        _ = q.dequeue()
        
        XCTAssertEqual(q.first, 0)
        XCTAssertEqual(q.last, Int64.min)
        
        _ = q.dequeue()
        
        XCTAssertEqual(q.first, q.last)
        
        _ = q.dequeue()
        
        XCTAssertNil(q.first)
        XCTAssertNil(q.last)
    }
    
    func testRepeatedUse() {
        let q = Queue<Int>()
        
        for i in 0...100 {
            q.enqueue(i)
            XCTAssertEqual(q.toArray().count-1, i)
            XCTAssertEqual(q.toArray()[i], i)
        }
        
        for i in 0...100 {
            XCTAssertEqual(q.toArray().count-1, 100-i)
            if i < q.toArray().count {
                XCTAssertEqual(q.toArray()[i], 2*i)
            }
            XCTAssertEqual(q.toArray()[0], i)
            XCTAssertEqual(q.dequeue(), i)
        }
    }
	
	func testAddNil() {
		let sut = Queue<Int?>()
        XCTAssert(sut.dequeue() == nil)
		sut.enqueue(nil)
        XCTAssert(sut.dequeue()! == nil)
		XCTAssert(sut.dequeue() == nil)
        
		sut.enqueue(2)
		sut.enqueue(nil)
		sut.enqueue(4)
		
		XCTAssertEqual(sut.dequeue()!, 2)
        XCTAssert(sut.dequeue()! == nil)
		XCTAssertEqual(sut.dequeue()!, 4)
        XCTAssert(sut.dequeue() == nil)
	}

	func testAddAfterEmpty() {
		let sut = Queue<String>()
		
		sut.enqueue("1")
		XCTAssertEqual(sut.dequeue()!, "1")
		XCTAssertNil(sut.dequeue())
		
		sut.enqueue("1")
		sut.enqueue("2")
		XCTAssertEqual(sut.dequeue()!, "1")
		XCTAssertEqual(sut.dequeue()!, "2")
		XCTAssert(sut.isEmpty)
		XCTAssertNil(sut.dequeue())
	}
	
	func testAddAndRemoveChaotically() {
		let sut = Queue<String>()
		
		sut.enqueue("1")
		XCTAssertFalse(sut.isEmpty)
		XCTAssertEqual(sut.dequeue()!, "1")
		XCTAssert(sut.isEmpty)
		XCTAssertNil(sut.dequeue())

		sut.enqueue("1")
		sut.enqueue("2")
		XCTAssertEqual(sut.dequeue()!, "1")
		XCTAssertEqual(sut.dequeue()!, "2")
		XCTAssert(sut.isEmpty)
		XCTAssertNil(sut.dequeue())

		sut.enqueue("1")
		sut.enqueue("2")
		XCTAssertEqual(sut.dequeue()!, "1")
		sut.enqueue("3")
		sut.enqueue("4")
		XCTAssertEqual(sut.dequeue()!, "2")
		XCTAssertEqual(sut.dequeue()!, "3")
		XCTAssertFalse(sut.isEmpty)
		XCTAssertEqual(sut.dequeue()!, "4")
		XCTAssertNil(sut.dequeue())
		XCTAssertNil(sut.dequeue())
	}

	func testConcurrency() {
        let sut = Queue<Int>()
		let numberofiterations = 2_000_00

		let addingexpectation = expectation(description: "adding completed")
		let addingqueue = DispatchQueue( label: "adding", attributes: [])
		addingqueue.async  {
			for i in 1...numberofiterations {
				sut.enqueue(i)
			}
			addingexpectation.fulfill()
		}
		
		let deletingexpectation = expectation(description: "deleting completed")
		let deletingqueue = DispatchQueue( label: "deleting", attributes: [])
		deletingqueue.async  {
            var i = 1
            while i <= numberofiterations {
                if let result = sut.dequeue() {
                    XCTAssertEqual(result, i)
                    i += 1
                } else {
                    print(" pausing deleting for 1mus")
                    usleep(1000)
                }
            }
			deletingexpectation.fulfill()
		}
		
		waitForExpectations( timeout: 600, handler:  nil)
	} 
}
