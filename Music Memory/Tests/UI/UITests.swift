import XCTest

class MusicMemoryUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }

    func testInitialPermissionRequest() throws {
        // Verify the permission request screen appears
        XCTAssertTrue(app.staticTexts["Music Library Access"].exists)
        XCTAssertTrue(app.buttons["Allow Access"].exists)
        
        // Tap the allow button
        app.buttons["Allow Access"].tap()
        
        // Verify the app moves to the song list or shows system permission alert
        // Note: Can't test system alerts in UI tests without special handling
        let songListExists = app.navigationBars["Music Memory"].waitForExistence(timeout: 2.0)
        let permissionDeniedExists = app.staticTexts["Permission Denied"].exists
        
        XCTAssertTrue(songListExists || permissionDeniedExists,
                     "App should either show the song list or permission denied screen")
    }
    
    func testSongListNavigation() throws {
        // This test assumes permissions are granted in the test environment
        
        // Use launch arguments to skip permission handling in test mode
        app.launchArguments = ["UI_TESTING", "SKIP_PERMISSIONS"]
        app.launch()
        
        // Verify navigation title exists
        XCTAssertTrue(app.navigationBars["Music Memory"].exists)
        
        // Wait for songs to load
        let predicate = NSPredicate(format: "count > 0")
        expectation(for: predicate, evaluatedWith: app.cells, handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
        
        // Tap the first song if any exist
        if app.cells.count > 0 {
            app.cells.element(boundBy: 0).tap()
            
            // Verify we navigate to song detail
            // Look for play count which should be present in detail view
            XCTAssertTrue(app.staticTexts["Play Count"].waitForExistence(timeout: 2.0))
            
            // Navigate back
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }
    
    func testEmptyStateView() throws {
        // Launch with argument to simulate empty library
        app.launchArguments = ["UI_TESTING", "EMPTY_LIBRARY"]
        app.launch()
        
        // Verify empty state appears
        XCTAssertTrue(app.staticTexts["No Songs Found"].waitForExistence(timeout: 2.0))
    }
}

// Extensions to help with testing
extension XCUIApplication {
    func waitForElementToAppear(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
