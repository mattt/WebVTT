# WebVTT

A WebVTT (Web Video Text Tracks) parser and generator for Swift.

[WebVTT][specification] is a W3C standard for displaying timed text tracks 
(such as subtitles or captions) 
used with HTML5 audio and video elements. 

This library provides a complete implementation for 
parsing, creating, and generating WebVTT content with support for 
regions, styles, and advanced cue positioning.

## Requirements

* Swift 6.0+ / Xcode 16+

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mattt/WebVTT.git", from: "1.0.0")
]
```

## Usage

### Basic Operations

```swift
import WebVTT

// Parse WebVTT content from a string
let vttContent = #"""
WEBVTT

00:00:05.000 --> 00:00:08.000
Hello, world!

00:00:10.000 --> 00:00:13.000
This is a subtitle.
"""#

let webVTT = try WebVTT.parse(vttContent)
print(webVTT.cues.count) // 2

// Create a new WebVTT file
var webVTT = WebVTT()
webVTT.cues.append(WebVTT.Cue(
    startTime: .init(minutes: 0, seconds: 5, milliseconds: 0),
    endTime: .init(minutes: 0, seconds: 8, milliseconds: 500),
    text: "Hello, world!"
))
```

### Working with Timestamps

```swift
// Create timestamps from individual components
let timestamp = WebVTT.Timestamp(hours: 1, minutes: 30, seconds: 45, milliseconds: 500)

// Create from total milliseconds
let timestamp2 = WebVTT.Timestamp(totalMilliseconds: 5445500)

// Parse from string
let timestamp3 = WebVTT.Timestamp.parse("01:30:45.500")

// String literal syntax
let timestamp4: WebVTT.Timestamp = "05:30.100"

// Format as WebVTT string
print(timestamp.description) // "01:30:45.500"
```

### Finding Active Cues

```swift
// Get active cues at a specific time
let currentTime = WebVTT.Timestamp(minutes: 0, seconds: 6, milliseconds: 500)
let activeCues = webVTT.activeCues(at: currentTime)

for cue in activeCues {
    print("Active: \(cue.text)")
}

// Check for overlapping cues
let cue1 = WebVTT.Cue(
    startTime: "00:05.000",
    endTime: "00:08.000",
    text: "First cue"
)

let cue2 = WebVTT.Cue(
    startTime: "00:07.000",
    endTime: "00:10.000",
    text: "Second cue"
)

let overlaps = cue1.overlaps(with: cue2) // true
```

### Advanced Cue Positioning

```swift
var cue = WebVTT.Cue(
    startTime: "00:05.000",
    endTime: "00:08.000",
    text: "Positioned cue"
)

// Set line position (80% from top)
cue.settings.line = .percentage(80)

// Set horizontal position (center)
cue.settings.position = .init(value: 50, alignment: .center)

// Set text alignment
cue.settings.align = .center

// Set size (60% of video width)
cue.settings.size = 60

// Set vertical writing direction
cue.settings.vertical = .rl
```

### Regions and Styling

```swift
// Create a region for cue positioning
var region = WebVTT.Region(id: "subtitle")
region.width = 80.0  // 80% of video width
region.lines = 2      // Show 2 lines of text
region.regionAnchor = (x: 50, y: 100)  // Center bottom of region
region.viewportAnchor = (x: 50, y: 90) // Center bottom of video

// Add CSS styling
let style = WebVTT.Style(css: #"""
::cue {
    color: yellow;
    font-size: 20px;
    font-family: Arial, sans-serif;
}
"""#)

// Associate cue with region
cue.settings.region = "subtitle"

var webVTT = WebVTT()
webVTT.regions.append(region)
webVTT.styles.append(style)
webVTT.cues.append(cue)
```

## License

WebVTT is available under the MIT license. 
See the LICENSE file for more info.

[specification]: https://www.w3.org/TR/webvtt1/