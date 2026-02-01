//
//  TrimSliderTests.swift
//  DevCamTests
//
//  Unit tests for TrimSliderView logic including position/time conversions
//  and boundary clamping behavior.
//

import XCTest
@testable import DevCam

/// Test helper that mirrors TrimSliderView's private calculation logic.
/// This allows testing the mathematical operations without accessing private members.
struct TrimSliderLogic {
    let minimumDuration: Double = 1.0

    /// Converts a position on the slider track to a time value.
    func positionToTime(_ position: CGFloat, trackWidth: CGFloat, duration: Double) -> Double {
        guard duration > 0, trackWidth > 0 else { return 0 }
        let percentage = position / trackWidth
        return Double(percentage) * duration
    }

    /// Converts a time value to a position on the slider track.
    func timeToPosition(_ time: Double, trackWidth: CGFloat, duration: Double) -> CGFloat {
        guard duration > 0 else { return 0 }
        let percentage = time / duration
        return CGFloat(percentage) * trackWidth
    }

    /// Clamps the start time to ensure it stays within valid bounds.
    /// Start time must be >= 0 and <= endTime - minimumDuration.
    func clampStartTime(_ newStart: Double, endTime: Double, duration: Double) -> Double {
        let maxStart = endTime - minimumDuration
        return max(0, min(newStart, maxStart))
    }

    /// Clamps the end time to ensure it stays within valid bounds.
    /// End time must be >= startTime + minimumDuration and <= duration.
    func clampEndTime(_ newEnd: Double, startTime: Double, duration: Double) -> Double {
        let minEnd = startTime + minimumDuration
        return max(minEnd, min(newEnd, duration))
    }
}

final class TrimSliderTests: XCTestCase {
    var logic: TrimSliderLogic!

    override func setUp() {
        super.setUp()
        logic = TrimSliderLogic()
    }

    override func tearDown() {
        logic = nil
        super.tearDown()
    }

    // MARK: - Position to Time Conversion Tests

    func testPositionToTimeConversion() {
        // Test basic conversion with a 60-second clip and 300px track
        let trackWidth: CGFloat = 300
        let duration: Double = 60.0

        // Position at start (0px) should be 0 seconds
        XCTAssertEqual(logic.positionToTime(0, trackWidth: trackWidth, duration: duration), 0,
                       "Position 0 should convert to time 0")

        // Position at middle (150px) should be 30 seconds
        XCTAssertEqual(logic.positionToTime(150, trackWidth: trackWidth, duration: duration), 30,
                       "Position at 50% should convert to 50% of duration")

        // Position at end (300px) should be 60 seconds
        XCTAssertEqual(logic.positionToTime(300, trackWidth: trackWidth, duration: duration), 60,
                       "Position at 100% should convert to full duration")

        // Position at 25% (75px) should be 15 seconds
        XCTAssertEqual(logic.positionToTime(75, trackWidth: trackWidth, duration: duration), 15,
                       "Position at 25% should convert to 25% of duration")
    }

    // MARK: - Time to Position Conversion Tests

    func testTimeToPositionConversion() {
        // Test basic conversion with a 60-second clip and 300px track
        let trackWidth: CGFloat = 300
        let duration: Double = 60.0

        // Time 0 should be at position 0
        XCTAssertEqual(logic.timeToPosition(0, trackWidth: trackWidth, duration: duration), 0,
                       "Time 0 should convert to position 0")

        // Time 30 (middle) should be at position 150
        XCTAssertEqual(logic.timeToPosition(30, trackWidth: trackWidth, duration: duration), 150,
                       "Time at 50% should convert to 50% position")

        // Time 60 (end) should be at position 300
        XCTAssertEqual(logic.timeToPosition(60, trackWidth: trackWidth, duration: duration), 300,
                       "Time at 100% should convert to 100% position")

        // Time 15 (25%) should be at position 75
        XCTAssertEqual(logic.timeToPosition(15, trackWidth: trackWidth, duration: duration), 75,
                       "Time at 25% should convert to 25% position")
    }

    // MARK: - Zero Duration Handling Tests

    func testZeroDurationHandling() {
        let trackWidth: CGFloat = 300
        let duration: Double = 0.0

        // Position to time with zero duration should return 0
        XCTAssertEqual(logic.positionToTime(150, trackWidth: trackWidth, duration: duration), 0,
                       "Position to time with zero duration should return 0")

        // Time to position with zero duration should return 0
        XCTAssertEqual(logic.timeToPosition(30, trackWidth: trackWidth, duration: duration), 0,
                       "Time to position with zero duration should return 0")
    }

    // MARK: - Zero Track Width Handling Tests

    func testZeroTrackWidthHandling() {
        let trackWidth: CGFloat = 0
        let duration: Double = 60.0

        // Position to time with zero track width should return 0
        XCTAssertEqual(logic.positionToTime(150, trackWidth: trackWidth, duration: duration), 0,
                       "Position to time with zero track width should return 0")
    }

    // MARK: - Minimum Duration Enforcement Tests

    func testMinimumDurationEnforcement() {
        let duration: Double = 60.0
        let endTime: Double = 30.0

        // Verify minimum duration constant
        XCTAssertEqual(logic.minimumDuration, 1.0,
                       "Minimum duration should be 1 second")

        // Trying to set start time too close to end time should clamp
        let attemptedStart = endTime - 0.5  // 0.5 seconds before end
        let clampedStart = logic.clampStartTime(attemptedStart, endTime: endTime, duration: duration)

        XCTAssertEqual(clampedStart, endTime - logic.minimumDuration,
                       "Start time should be clamped to endTime - minimumDuration")

        // Verify the resulting gap is at least minimumDuration
        XCTAssertGreaterThanOrEqual(endTime - clampedStart, logic.minimumDuration,
                                    "Gap between start and end should be at least minimumDuration")
    }

    // MARK: - Start Time Clamping Tests

    func testStartTimeClamping() {
        let duration: Double = 60.0
        let endTime: Double = 30.0

        // Test clamping negative values to 0
        XCTAssertEqual(logic.clampStartTime(-10, endTime: endTime, duration: duration), 0,
                       "Negative start time should be clamped to 0")

        // Test clamping values beyond max allowed
        XCTAssertEqual(logic.clampStartTime(50, endTime: endTime, duration: duration),
                       endTime - logic.minimumDuration,
                       "Start time beyond max should be clamped to endTime - minimumDuration")

        // Test valid value passes through
        XCTAssertEqual(logic.clampStartTime(15, endTime: endTime, duration: duration), 15,
                       "Valid start time should not be modified")

        // Test boundary value at 0
        XCTAssertEqual(logic.clampStartTime(0, endTime: endTime, duration: duration), 0,
                       "Start time at 0 should remain 0")

        // Test boundary value at max allowed
        let maxAllowed = endTime - logic.minimumDuration
        XCTAssertEqual(logic.clampStartTime(maxAllowed, endTime: endTime, duration: duration), maxAllowed,
                       "Start time at max allowed should remain unchanged")
    }

    // MARK: - End Time Clamping Tests

    func testEndTimeClamping() {
        let duration: Double = 60.0
        let startTime: Double = 30.0

        // Test clamping values below minimum
        let minAllowed = startTime + logic.minimumDuration
        XCTAssertEqual(logic.clampEndTime(30.5, startTime: startTime, duration: duration), minAllowed,
                       "End time too close to start should be clamped to startTime + minimumDuration")

        // Test clamping values beyond duration
        XCTAssertEqual(logic.clampEndTime(100, startTime: startTime, duration: duration), duration,
                       "End time beyond duration should be clamped to duration")

        // Test valid value passes through
        XCTAssertEqual(logic.clampEndTime(45, startTime: startTime, duration: duration), 45,
                       "Valid end time should not be modified")

        // Test boundary value at min allowed
        XCTAssertEqual(logic.clampEndTime(minAllowed, startTime: startTime, duration: duration), minAllowed,
                       "End time at min allowed should remain unchanged")

        // Test boundary value at duration
        XCTAssertEqual(logic.clampEndTime(duration, startTime: startTime, duration: duration), duration,
                       "End time at duration should remain unchanged")
    }

    // MARK: - Round Trip Conversion Tests

    func testRoundTripConversion() {
        let trackWidth: CGFloat = 300
        let duration: Double = 60.0

        // Test round-trip: position -> time -> position
        let originalPositions: [CGFloat] = [0, 75, 150, 225, 300]

        for originalPosition in originalPositions {
            let time = logic.positionToTime(originalPosition, trackWidth: trackWidth, duration: duration)
            let convertedPosition = logic.timeToPosition(time, trackWidth: trackWidth, duration: duration)

            XCTAssertEqual(convertedPosition, originalPosition, accuracy: 0.001,
                           "Round-trip position -> time -> position should yield same result for \(originalPosition)")
        }

        // Test round-trip: time -> position -> time
        let originalTimes: [Double] = [0, 15, 30, 45, 60]

        for originalTime in originalTimes {
            let position = logic.timeToPosition(originalTime, trackWidth: trackWidth, duration: duration)
            let convertedTime = logic.positionToTime(position, trackWidth: trackWidth, duration: duration)

            XCTAssertEqual(convertedTime, originalTime, accuracy: 0.001,
                           "Round-trip time -> position -> time should yield same result for \(originalTime)")
        }
    }

    // MARK: - Additional Edge Case Tests

    func testNegativePositionHandling() {
        let trackWidth: CGFloat = 300
        let duration: Double = 60.0

        // Negative position should result in negative time (caller should clamp)
        let time = logic.positionToTime(-30, trackWidth: trackWidth, duration: duration)
        XCTAssertLessThan(time, 0,
                          "Negative position should produce negative time before clamping")
    }

    func testVerySmallDurationHandling() {
        let trackWidth: CGFloat = 300
        let duration: Double = 0.1  // Very short clip

        // Should still work with very small durations
        let time = logic.positionToTime(150, trackWidth: trackWidth, duration: duration)
        XCTAssertEqual(time, 0.05, accuracy: 0.0001,
                       "Should handle very small durations correctly")

        let position = logic.timeToPosition(0.05, trackWidth: trackWidth, duration: duration)
        XCTAssertEqual(position, 150, accuracy: 0.1,
                       "Should convert back correctly with small durations")
    }

    func testLargeDurationHandling() {
        let trackWidth: CGFloat = 300
        let duration: Double = 3600.0  // 1 hour clip

        // Position at middle should convert to 30 minutes
        let time = logic.positionToTime(150, trackWidth: trackWidth, duration: duration)
        XCTAssertEqual(time, 1800, accuracy: 0.001,
                       "Should handle large durations correctly")

        // 30 minutes should convert to middle position
        let position = logic.timeToPosition(1800, trackWidth: trackWidth, duration: duration)
        XCTAssertEqual(position, 150, accuracy: 0.001,
                       "Should convert large times to positions correctly")
    }

    func testClampingWithMinimalEndTime() {
        let duration: Double = 60.0

        // When end time equals minimum duration, start can only be 0
        let endTime = logic.minimumDuration  // 1.0 second
        let clampedStart = logic.clampStartTime(0.5, endTime: endTime, duration: duration)

        XCTAssertEqual(clampedStart, 0,
                       "When end time is at minimum, start should be clamped to 0")
    }

    func testClampingWithStartAtMaximum() {
        let duration: Double = 60.0

        // When start time is at maximum possible, end must be at duration
        let startTime = duration - logic.minimumDuration  // 59.0 seconds
        let clampedEnd = logic.clampEndTime(59.5, startTime: startTime, duration: duration)

        XCTAssertEqual(clampedEnd, duration,
                       "When start is near max, end should clamp to duration if value exceeds it")
    }
}
