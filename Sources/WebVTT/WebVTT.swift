/// A WebVTT (Web Video Text Tracks) parser and generator for Swift.
///
/// [WebVTT](https://www.w3.org/TR/webvtt1/)
/// is a W3C standard for displaying timed text tracks
/// (such as subtitles or captions)
/// used with HTML5 audio and video elements.
/// This library provides a complete implementation
/// for parsing, creating, and generating WebVTT content.
///
/// ## Overview
///
/// The `WebVTT` struct represents a complete WebVTT file containing:
/// - **Regions**: Define areas of the video where cues are displayed
/// - **Styles**: CSS styling for cue appearance
/// - **Cues**: Timed text entries with positioning and formatting options
///
/// ## Basic Usage
///
/// ```swift
/// // Parse WebVTT content from a string
/// let webVTT = try WebVTT.parse(vttContent)
///
/// // Create a new WebVTT file
/// var webVTT = WebVTT()
/// webVTT.cues.append(Cue(
///     startTime: .init(minutes: 0, seconds: 5, milliseconds: 0),
///     endTime: .init(minutes: 0, seconds: 8, milliseconds: 500),
///     text: "Hello, world!"
/// ))
///
/// // Get active cues at a specific time
/// let activeCues = webVTT.activeCues(at: .init(minutes: 0, seconds: 6, milliseconds: 0))
/// ```
public struct WebVTT: Sendable, Hashable, Codable {

    // MARK: - Timestamp

    /// A timestamp representing a specific point in time within a WebVTT file.
    ///
    /// WebVTT timestamps are typically formatted as
    /// `HH:MM:SS.mmm` or `MM:SS.mmm`,
    /// where hours are optional.
    ///
    /// ## Creating Timestamps
    ///
    /// ```swift
    /// // Create from individual components
    /// let timestamp = WebVTT.Timestamp(hours: 1, minutes: 30, seconds: 45, milliseconds: 500)
    ///
    /// // Create from total milliseconds
    /// let timestamp = WebVTT.Timestamp(totalMilliseconds: 5445500)
    ///
    /// // Format as WebVTT string
    /// print(timestamp.description) // "01:30:45.500"
    /// ```
    ///
    /// ## Time Components
    ///
    /// Access individual time components for display or calculation:
    /// - `hours`: Hours component (0-23)
    /// - `minutes`: Minutes component (0-59)
    /// - `seconds`: Seconds component (0-59)
    /// - `milliseconds`: Milliseconds component (0-999)
    /// - `totalMilliseconds`: Total time in milliseconds
    public struct Timestamp: Comparable, Equatable, Sendable, Hashable, Codable,
        ExpressibleByStringLiteral
    {
        /// The total time in milliseconds.
        ///
        /// This value represents the complete timestamp as a single integer,
        /// making it easy to perform time calculations and comparisons.
        public let totalMilliseconds: Int

        /// The hours component of the timestamp.
        ///
        /// Returns a value from 0 to 23 representing the hours portion
        /// of the timestamp.
        public var hours: Int { totalMilliseconds / 3_600_000 }

        /// The minutes component of the timestamp.
        ///
        /// Returns a value from 0 to 59 representing the minutes portion
        /// of the timestamp.
        public var minutes: Int { (totalMilliseconds % 3_600_000) / 60_000 }

        /// The seconds component of the timestamp.
        ///
        /// Returns a value from 0 to 59 representing the seconds portion
        /// of the timestamp.
        public var seconds: Int { (totalMilliseconds % 60_000) / 1_000 }

        /// The milliseconds component of the timestamp.
        ///
        /// Returns a value from 0 to 999 representing the milliseconds portion
        /// of the timestamp.
        public var milliseconds: Int { totalMilliseconds % 1_000 }

        /// Creates a timestamp from individual time components.
        ///
        /// - Parameters:
        ///   - hours: The hours component (0-23). Defaults to 0.
        ///   - minutes: The minutes component (0-59).
        ///   - seconds: The seconds component (0-59).
        ///   - milliseconds: The milliseconds component (0-999).
        ///
        /// - Note: All components are automatically normalized to their valid ranges.
        ///   For example, 65 seconds will be converted to 1 minute and 5 seconds.
        public init(hours: Int = 0, minutes: Int, seconds: Int, milliseconds: Int) {
            self.totalMilliseconds =
                hours * 3_600_000 + minutes * 60_000 + seconds * 1_000 + milliseconds
        }

        /// Creates a timestamp from total milliseconds.
        ///
        /// - Parameter totalMilliseconds: The total time in milliseconds.
        ///   Must be non-negative.
        public init(totalMilliseconds: Int) {
            self.totalMilliseconds = totalMilliseconds
        }

        // MARK: - ExpressibleByStringLiteral

        /// Creates a timestamp from a string literal.
        ///
        /// This allows timestamps to be created directly from string literals
        /// using the WebVTT timestamp format (e.g., "01:30:45.500").
        ///
        /// - Parameter value: The timestamp string to parse.
        /// - Throws: A fatal error if the string cannot be parsed as a valid timestamp.
        public init(stringLiteral value: String) {
            guard let timestamp = Self.parse(value) else {
                fatalError(
                    "Invalid timestamp format: \(value). Expected format: HH:MM:SS.mmm, MM:SS.mmm, or SS.mmm"
                )
            }
            self.totalMilliseconds = timestamp.totalMilliseconds
        }

        /// Compares two timestamps for ordering.
        ///
        /// Timestamps are compared based on their total milliseconds value.
        /// This allows for natural sorting and time-based comparisons.
        public static func < (lhs: Timestamp, rhs: Timestamp) -> Bool {
            lhs.totalMilliseconds < rhs.totalMilliseconds
        }

        /// Returns the timestamp formatted as a WebVTT string.
        ///
        /// The formatted string follows the WebVTT specification:
        /// - Uses `HH:MM:SS.mmm` format when hours > 0
        /// - Uses `MM:SS.mmm` format when hours = 0
        /// - All components are zero-padded to maintain consistent width
        ///
        /// ## Examples
        ///
        /// ```swift
        /// let timestamp1 = Timestamp(hours: 1, minutes: 30, seconds: 45, milliseconds: 500)
        /// print(timestamp1.description) // "01:30:45.500"
        ///
        /// let timestamp2 = Timestamp(minutes: 5, seconds: 30, milliseconds: 100)
        /// print(timestamp2.description) // "05:30.100"
        /// ```
        public var description: String {
            func pad(_ value: Int, to width: Int) -> String {
                let str = String(value)
                let padding =
                    width > str.count ? String(repeating: "0", count: width - str.count) : ""
                return padding + str
            }

            if hours != 0 {
                return
                    "\(pad(hours, to: 2)):\(pad(minutes, to: 2)):\(pad(seconds, to: 2)).\(pad(milliseconds, to: 3))"
            } else {
                return "\(pad(minutes, to: 2)):\(pad(seconds, to: 2)).\(pad(milliseconds, to: 3))"
            }
        }

        // MARK: - Codable

        /// Encodes the timestamp as a single string value.
        ///
        /// The timestamp is encoded using its WebVTT string representation
        /// (e.g., "01:30:45.500" or "05:30.100") for better readability
        /// in JSON and other encoded formats.
        ///
        /// - Parameter encoder: The encoder to encode into.
        /// - Throws: An error if encoding fails.
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(description)
        }

        /// Decodes the timestamp from a single string value.
        ///
        /// The timestamp is decoded from its WebVTT string representation.
        /// This method supports the same formats as `parseTimestamp`:
        /// - `HH:MM:SS.mmm` (hours, minutes, seconds, milliseconds)
        /// - `MM:SS.mmm` (minutes, seconds, milliseconds)
        /// - `SS.mmm` (seconds, milliseconds)
        ///
        /// - Parameter decoder: The decoder to decode from.
        /// - Throws: A `DecodingError` if the string format is invalid.
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            guard let timestamp = Self.parse(string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription:
                        "Invalid timestamp format: \(string). Expected format: HH:MM:SS.mmm, MM:SS.mmm, or SS.mmm"
                )
            }

            self.totalMilliseconds = timestamp.totalMilliseconds
        }

        // MARK: - Static Parsing

        /// Parses a timestamp string into a `Timestamp` instance.
        ///
        /// This method supports multiple timestamp formats:
        /// - `HH:MM:SS.mmm` (hours, minutes, seconds, milliseconds)
        /// - `MM:SS.mmm` (minutes, seconds, milliseconds)
        /// - `SS.mmm` (seconds, milliseconds)
        ///
        /// - Parameter string: The timestamp string to parse.
        /// - Returns: A `Timestamp` instance if parsing succeeds, `nil` otherwise.
        public static func parse(_ string: String) -> Timestamp? {
            let components = string.split(separator: ":")

            if components.count == 2 {
                // MM:SS.mmm format
                guard let minutes = Int(components[0]) else { return nil }
                let secondsComponents = components[1].split(separator: ".")
                guard secondsComponents.count == 2,
                    let seconds = Int(secondsComponents[0]),
                    let milliseconds = Int(secondsComponents[1])
                else { return nil }

                return Timestamp(
                    minutes: minutes, seconds: seconds, milliseconds: milliseconds)
            } else if components.count == 3 {
                // HH:MM:SS.mmm format
                guard let hours = Int(components[0]),
                    let minutes = Int(components[1])
                else { return nil }
                let secondsComponents = components[2].split(separator: ".")
                guard secondsComponents.count == 2,
                    let seconds = Int(secondsComponents[0]),
                    let milliseconds = Int(secondsComponents[1])
                else { return nil }

                return Timestamp(
                    hours: hours, minutes: minutes, seconds: seconds, milliseconds: milliseconds)
            }

            // Support SS.mmm form
            if components.count == 1 {
                let secondsComponents = string.split(separator: ".")
                guard secondsComponents.count == 2,
                    let seconds = Int(secondsComponents[0]),
                    let milliseconds = Int(secondsComponents[1])
                else { return nil }

                return Timestamp(minutes: 0, seconds: seconds, milliseconds: milliseconds)
            }

            return nil
        }
    }

    // MARK: - Region

    /// A region defines an area of the video where cues are displayed.
    ///
    /// Regions allow you to control the positioning and layout of multiple cues
    /// within the video player. Each region can have its own size, position,
    /// and scrolling behavior.
    ///
    /// ## Creating Regions
    ///
    /// ```swift
    /// var region = Region(id: "subtitle")
    /// region.width = 80.0  // 80% of video width
    /// region.lines = 2      // Show 2 lines of text
    /// region.regionAnchor = (x: 50, y: 100)  // Center bottom of region
    /// region.viewportAnchor = (x: 50, y: 90) // Center bottom of video
    /// ```
    ///
    /// ## Region Properties
    ///
    /// - `id`: Unique identifier for the region
    /// - `width`: Width as percentage of video width (default: 100%)
    /// - `lines`: Number of text lines to display (default: 3)
    /// - `regionAnchor`: Anchor point within the region (default: 0%, 100%)
    /// - `viewportAnchor`: Anchor point within the video viewport (default: 0%, 100%)
    /// - `scroll`: Scrolling direction (currently only supports "up")
    public struct Region: Sendable, Hashable, Codable, Identifiable {
        /// The unique identifier for this region.
        ///
        /// This ID is used to associate cues with specific regions
        /// using the `region` cue setting.
        public var id: String

        /// The width of the region as a percentage of the video width.
        ///
        /// Valid values range from 0 to 100. The default value is 100,
        /// meaning the region spans the full width of the video.
        public var width: Double = 100

        /// The number of text lines to display in this region.
        ///
        /// This controls how much vertical space the region occupies.
        /// The default value is 3 lines.
        public var lines: Int = 3

        /// The anchor point within the region.
        ///
        /// This defines which point of the region is positioned relative
        /// to the viewport anchor. Values are percentages where (0,0)
        /// is the top-left and (100,100) is the bottom-right.
        ///
        /// The default value is (0, 100), meaning the bottom-left corner
        /// of the region.
        private var regionAnchorX: Double = 0
        private var regionAnchorY: Double = 100
        public var regionAnchor: (x: Double, y: Double) {
            get { (regionAnchorX, regionAnchorY) }
            set {
                regionAnchorX = newValue.x
                regionAnchorY = newValue.y
            }
        }

        /// The anchor point within the video viewport.
        ///
        /// This defines where the region anchor point is positioned
        /// within the video player. Values are percentages where (0,0)
        /// is the top-left and (100,100) is the bottom-right.
        ///
        /// The default value is (0, 100), meaning the bottom-left corner
        /// of the video.
        private var viewportAnchorX: Double = 0
        private var viewportAnchorY: Double = 100
        public var viewportAnchor: (x: Double, y: Double) {
            get { (viewportAnchorX, viewportAnchorY) }
            set {
                viewportAnchorX = newValue.x
                viewportAnchorY = newValue.y
            }
        }

        /// The scrolling direction for this region.
        ///
        /// Currently, only upward scrolling is supported by the WebVTT
        /// specification. When set to `.up`, cues will scroll upward
        /// through the region as new ones appear.
        public enum ScrollDirection: String, Sendable, Hashable, Codable, CaseIterable {
            /// Scroll cues upward through the region.
            case up = "up"
        }
        public var scroll: ScrollDirection?

        /// Creates a new region with the specified identifier.
        ///
        /// - Parameter id: The unique identifier for this region.
        ///   This ID is used to associate cues with the region.
        public init(id: String) {
            self.id = id
        }
    }

    /// The regions defined in this WebVTT file.
    ///
    /// Regions define areas of the video where cues can be displayed.
    /// Each region can have its own size, position, and scrolling behavior.
    public var regions: [Region]

    // MARK: - Style

    /// A CSS style block for styling WebVTT cues.
    ///
    /// Style blocks contain CSS rules that control the appearance of cues
    /// within the video player. The CSS is applied to cue elements based
    /// on their selectors and classes.
    ///
    /// ## Creating Styles
    ///
    /// ```swift
    /// let style = Style(css: """
    /// ::cue {
    ///     color: yellow;
    ///     font-size: 20px;
    ///     font-family: Arial, sans-serif;
    /// }
    /// """)
    /// ```
    ///
    /// ## CSS Support
    ///
    /// The CSS can include any valid CSS rules that apply to cue elements,
    /// including:
    /// - `::cue` pseudo-element selectors
    /// - Class-based selectors (e.g., `.subtitle`)
    /// - Font properties (size, family, weight, etc.)
    /// - Color and background properties
    /// - Text alignment and positioning
    public struct Style: Sendable, Hashable, Codable {
        /// The CSS content for this style block.
        ///
        /// This should contain valid CSS rules that will be applied
        /// to cue elements in the video player.
        public let css: String

        /// Creates a new style block with the specified CSS content.
        ///
        /// - Parameter css: The CSS rules to apply to cues.
        public init(css: String) {
            self.css = css
        }
    }

    /// The style blocks defined in this WebVTT file.
    ///
    /// These CSS style blocks control the appearance of cues
    /// within the video player.
    public var styles: [Style]

    // MARK: - Cue

    /// A WebVTT cue representing a timed text entry.
    ///
    /// Cues are the primary content of a WebVTT file, containing text that
    /// is displayed at specific times during video playback. Each cue has
    /// timing information, text content, and optional positioning settings.
    ///
    /// ## Creating Cues
    ///
    /// ```swift
    /// let cue = Cue(
    ///     startTime: Timestamp(minutes: 0, seconds: 5, milliseconds: 0),
    ///     endTime: Timestamp(minutes: 0, seconds: 8, milliseconds: 500),
    ///     text: "Hello, world!"
    /// )
    ///
    /// // Add positioning settings
    /// cue.settings.line = .percentage(80)  // 80% from top
    /// cue.settings.align = .center         // Center alignment
    /// ```
    ///
    /// ## Cue Properties
    ///
    /// - `id`: Optional identifier for the cue
    /// - `startTime`: When the cue should appear
    /// - `endTime`: When the cue should disappear
    /// - `settings`: Positioning and formatting options
    /// - `text`: The text content to display
    public struct Cue: Sendable, Hashable, Codable {
        /// An optional identifier for this cue.
        ///
        /// Cue IDs are used for styling specific cues with CSS
        /// or for programmatic access to individual cues.
        public var id: String?

        /// The timestamp when this cue should start displaying.
        ///
        /// The cue will become visible at this exact time during
        /// video playback.
        public var startTime: Timestamp

        /// The timestamp when this cue should stop displaying.
        ///
        /// The cue will disappear at this exact time during
        /// video playback.
        public var endTime: Timestamp

        /// The positioning and formatting settings for this cue.
        ///
        /// These settings control where and how the cue text
        /// is displayed within the video player.
        public var settings: Settings

        /// The text content to display for this cue.
        ///
        /// This can contain plain text or basic HTML markup
        /// depending on the video player's capabilities.
        public var text: String

        /// Settings that control the positioning and formatting of a cue.
        ///
        /// These settings allow fine-grained control over how cues
        /// are displayed within the video player, including position,
        /// alignment, size, and text direction.
        public struct Settings: Sendable, Hashable, Codable {
            /// The vertical writing direction for the cue text.
            ///
            /// This setting controls whether text flows vertically
            /// from left to right or right to left.
            public var vertical: WritingDirection?

            /// The line position where the cue should be displayed.
            ///
            /// This can be specified as a percentage of the video height,
            /// a specific line number, or automatically positioned.
            public var line: Line?

            /// The horizontal position where the cue should be displayed.
            ///
            /// This is specified as a percentage of the video width,
            /// with optional alignment settings.
            public var position: Position?

            /// The width of the cue text as a percentage of the video width.
            ///
            /// This controls how much horizontal space the cue text occupies.
            public var size: Double?

            /// The text alignment within the cue.
            ///
            /// This controls how the text is aligned within its allocated space.
            public var align: Alignment?

            /// The region where this cue should be displayed.
            ///
            /// This references a region by its ID. If specified, the cue
            /// will be displayed within that region instead of the default area.
            public var region: String?

            /// The vertical writing direction for cue text.
            ///
            /// These values control whether text flows vertically
            /// and in which direction.
            public enum WritingDirection: String, Sendable, Hashable, Codable, CaseIterable {
                /// Vertical text growing from right to left.
                case rl = "rl"
                /// Vertical text growing from left to right.
                case lr = "lr"
            }

            /// A line position setting for cue placement.
            ///
            /// Line positions can be specified as percentages, line numbers,
            /// or automatically determined by the video player.
            public struct Line: Sendable, Hashable, Codable {
                /// The line position value.
                ///
                /// This can be a percentage of the video height, a specific
                /// line number, or automatic positioning.
                public var value: Value

                /// The alignment of the cue within the line.
                ///
                /// This controls how the cue is positioned horizontally
                /// within its allocated line space.
                public var alignment: LineAlignment?

                /// The possible line position values.
                public enum Value: Sendable, Hashable, Codable {
                    /// Position as a percentage of the video height.
                    ///
                    /// Values range from 0 to 100, where 0 is the top
                    /// and 100 is the bottom of the video.
                    case percentage(Double)
                    /// Position at a specific line number.
                    ///
                    /// Line numbers start from 1 and increase downward.
                    /// Negative values count from the bottom.
                    case lineNumber(Int)
                    /// Automatically position the cue.
                    ///
                    /// The video player will determine the optimal
                    /// line position for the cue.
                    case auto
                }

                /// The alignment of a cue within its line.
                ///
                /// These values control how the cue is positioned
                /// horizontally within its allocated line space.
                public enum LineAlignment: String, Sendable, Hashable, Codable, CaseIterable {
                    /// Align to the start of the line (left for LTR text).
                    case start = "start"
                    /// Center the cue within the line.
                    case center = "center"
                    /// Align to the end of the line (right for LTR text).
                    case end = "end"
                }
            }

            /// A horizontal position setting for cue placement.
            ///
            /// Position settings control where cues are placed horizontally
            /// within the video player, with optional alignment options.
            public struct Position: Sendable, Hashable, Codable {
                /// The horizontal position as a percentage of the video width.
                ///
                /// Values range from 0 to 100, where 0 is the left edge
                /// and 100 is the right edge of the video.
                public var value: Double

                /// The alignment of the cue at the specified position.
                ///
                /// This controls how the cue is positioned relative to
                /// the specified horizontal position.
                public var alignment: PositionAlignment?

                /// The alignment of a cue at its horizontal position.
                ///
                /// These values control how the cue is positioned relative
                /// to its specified horizontal position.
                public enum PositionAlignment: String, Sendable, Hashable, Codable, CaseIterable {
                    /// Align the left edge of the cue to the position.
                    case lineLeft = "line-left"
                    /// Center the cue at the position.
                    case center = "center"
                    /// Align the right edge of the cue to the position.
                    case lineRight = "line-right"
                    /// Automatically determine alignment based on text direction.
                    case auto = "auto"
                }
            }

            /// The text alignment within a cue.
            ///
            /// These values control how the text is aligned within
            /// the cue's allocated space.
            public enum Alignment: String, Sendable, Hashable, Codable, CaseIterable {
                /// Align text to the start (left for LTR text).
                case start = "start"
                /// Center-align the text.
                case center = "center"
                /// Align text to the end (right for LTR text).
                case end = "end"
                /// Left-align the text.
                case left = "left"
                /// Right-align the text.
                case right = "right"
            }

            /// Creates a new settings instance with default values.
            ///
            /// All settings are initially `nil`, meaning the video player
            /// will use its default behavior for cue positioning and formatting.
            public init() {}
        }

        /// Creates a new cue with the specified timing and text.
        ///
        /// - Parameters:
        ///   - startTime: When the cue should start displaying.
        ///   - endTime: When the cue should stop displaying.
        ///   - text: The text content to display.
        ///
        /// - Note: The `endTime` must be greater than `startTime`.
        ///   All other properties (id, settings) are initialized with default values.
        public init(startTime: Timestamp, endTime: Timestamp, text: String) {
            self.startTime = startTime
            self.endTime = endTime
            self.text = text
            self.settings = Settings()
        }

        /// Checks if this cue overlaps in time with another cue.
        ///
        /// Two cues overlap if one starts before the other ends and ends after
        /// the other starts. This is useful for detecting timing conflicts
        /// or for determining which cues are active simultaneously.
        ///
        /// - Parameter other: The cue to check for overlap with.
        /// - Returns: `true` if the cues overlap in time, `false` otherwise.
        ///
        /// ## Example
        ///
        /// ```swift
        /// let cue1 = Cue(
        ///     startTime: Timestamp(minutes: 0, seconds: 5, milliseconds: 0),
        ///     endTime: Timestamp(minutes: 0, seconds: 8, milliseconds: 0),
        ///     text: "First cue"
        /// )
        ///
        /// let cue2 = Cue(
        ///     startTime: Timestamp(minutes: 0, seconds: 7, milliseconds: 0),
        ///     endTime: Timestamp(minutes: 0, seconds: 10, milliseconds: 0),
        ///     text: "Second cue"
        /// )
        ///
        /// let overlaps = cue1.overlaps(with: cue2) // true
        /// ```
        public func overlaps(with other: WebVTT.Cue) -> Bool {
            return startTime < other.endTime && endTime > other.startTime
        }

        /// The duration of this cue in milliseconds.
        ///
        /// This is calculated as the difference between the end time
        /// and start time of the cue.
        public var duration: Int {
            return endTime.totalMilliseconds - startTime.totalMilliseconds
        }
    }

    /// The cues defined in this WebVTT file.
    ///
    /// Cues are the primary content of a WebVTT file, containing
    /// timed text that is displayed during video playback.
    public var cues: [Cue]

    /// Creates a new WebVTT file with the specified components.
    ///
    /// - Parameters:
    ///   - regions: The regions to include in the file. Defaults to an empty array.
    ///   - styles: The style blocks to include in the file. Defaults to an empty array.
    ///   - cues: The cues to include in the file. Defaults to an empty array.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let webVTT = WebVTT(
    ///     regions: [Region(id: "subtitle")],
    ///     styles: [Style(css: "::cue { color: yellow; }")],
    ///     cues: [cue1, cue2, cue3]
    /// )
    /// ```
    public init(regions: [Region] = [], styles: [Style] = [], cues: [Cue] = []) {
        self.regions = regions
        self.styles = styles
        self.cues = cues
    }

    // MARK: - Parsing

    /// Errors that can occur during WebVTT parsing.
    ///
    /// These errors provide specific information about what went wrong
    /// during the parsing process, helping developers identify and fix
    /// issues with their WebVTT content.
    public enum ParseError: Error {
        /// The WebVTT file is missing or has an invalid signature.
        ///
        /// WebVTT files must begin with "WEBVTT" (optionally preceded
        /// by a UTF-8 BOM). This error occurs when the signature is
        /// missing, malformed, or not at the beginning of the file.
        case invalidSignature

        /// A timestamp in the WebVTT file has an invalid format.
        ///
        /// Timestamps must follow the format `HH:MM:SS.mmm` or `MM:SS.mmm`.
        /// This error occurs when a timestamp cannot be parsed due to
        /// incorrect formatting or invalid values.
        case invalidTimestamp

        /// A cue timing line has an invalid format.
        ///
        /// Cue timing lines must follow the format `start --> end [settings]`.
        /// This error occurs when the timing line cannot be parsed due to
        /// missing arrows, invalid timestamps, or malformed settings.
        case invalidCueTimings

        /// A region block contains invalid settings.
        ///
        /// Region settings must follow the format `key:value` and use
        /// valid values for each setting type. This error occurs when
        /// region settings cannot be parsed or contain invalid values.
        case invalidRegionSettings

        /// The WebVTT content is malformed in an unspecified way.
        ///
        /// This is a catch-all error for parsing issues that don't fit
        /// into the other specific error categories.
        case malformedInput
    }

    /// Parses WebVTT content from a string.
    ///
    /// This method parses a complete WebVTT file from its string representation,
    /// including all regions, styles, and cues. The parser is lenient and will
    /// attempt to recover from minor formatting issues when possible.
    ///
    /// - Parameter content: The WebVTT content as a string.
    /// - Returns: A `WebVTT` instance containing the parsed content.
    /// - Throws: `ParseError` if the content cannot be parsed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let vttContent = """
    /// WEBVTT
    ///
    /// 00:00:05.000 --> 00:00:08.000
    /// Hello, world!
    ///
    /// 00:00:10.000 --> 00:00:13.000
    /// This is a subtitle.
    /// """
    ///
    /// do {
    ///     let webVTT = try WebVTT.parse(vttContent)
    ///     print("Parsed \(webVTT.cues.count) cues")
    /// } catch {
    ///     print("Parse error: \(error)")
    /// }
    /// ```
    public static func parse(_ content: String) throws -> WebVTT {
        let parser = Parser()
        return try parser.parse(content)
    }

    /// Returns all cues that are active at the specified timestamp.
    ///
    /// A cue is considered active if the given timestamp falls within
    /// its start and end times (inclusive of start, exclusive of end).
    ///
    /// - Parameter timestamp: The timestamp to check for active cues.
    /// - Returns: An array of cues that are currently active at the timestamp.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let webVTT = try WebVTT.parse(vttContent)
    /// let currentTime = Timestamp(minutes: 0, seconds: 6, milliseconds: 500)
    /// let activeCues = webVTT.activeCues(at: currentTime)
    ///
    /// for cue in activeCues {
    ///     print("Active: \(cue.text)")
    /// }
    /// ```
    public func activeCues(at timestamp: Timestamp) -> [Cue] {
        return cues.filter { cue in
            timestamp >= cue.startTime && timestamp < cue.endTime
        }
    }

    /// Sorts all cues by their start time in ascending order.
    ///
    /// This method modifies the cues array in place, sorting them
    /// chronologically by their start time. This is useful for ensuring
    /// cues are in the correct order for processing or display.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var webVTT = try WebVTT.parse(vttContent)
    /// webVTT.sortCues()
    /// // Cues are now sorted by start time
    /// ```
    public mutating func sortCues() {
        cues.sort { $0.startTime < $1.startTime }
    }

    // MARK: - Parser

    /// A WebVTT parser implementation.
    ///
    /// This private class handles the parsing of WebVTT content from strings.
    /// It implements a robust parser that can handle various WebVTT formats
    /// and recover from minor formatting issues.
    private final class Parser: Sendable {
        // MARK: - Main Parsing

        /// Parses WebVTT content from a string.
        ///
        /// This method performs the main parsing logic, handling the WebVTT signature,
        /// regions, styles, and cues. It uses a block-based parsing approach to
        /// handle the different types of content that can appear in a WebVTT file.
        ///
        /// - Parameter content: The WebVTT content to parse.
        /// - Returns: A `WebVTT` instance containing the parsed content.
        /// - Throws: `ParseError` if the content cannot be parsed.
        func parse(_ content: String) throws -> WebVTT {
            var lines = content.splitByNewlines()

            // Check for WebVTT signature (may start with UTF-8 BOM and may include header text after the keyword)
            guard !lines.isEmpty else { throw WebVTT.ParseError.invalidSignature }

            var firstLine = lines[0].trimWhitespace()
            // Strip UTF-8 BOM if present
            if firstLine.hasPrefix("\u{FEFF}") {
                firstLine.removeFirst()
            }

            guard firstLine.hasPrefix("WEBVTT") else {
                throw WebVTT.ParseError.invalidSignature
            }

            // Remove the signature line and any empty lines after it
            lines.removeFirst()
            while !lines.isEmpty && lines[0].trimWhitespace().isEmpty {
                lines.removeFirst()
            }

            var regions: [WebVTT.Region] = []
            var styles: [WebVTT.Style] = []
            var cues: [WebVTT.Cue] = []

            var currentIndex = 0
            while currentIndex < lines.count {
                let block = try parseBlock(from: lines, startingAt: &currentIndex)
                switch block {
                case .region(let region):
                    regions.append(region)
                case .style(let style):
                    styles.append(style)
                case .cue(let cue):
                    cues.append(cue)
                case .note:
                    // Notes are ignored
                    break
                case .none:
                    // Skip empty lines
                    currentIndex += 1
                }
            }

            return WebVTT(regions: regions, styles: styles, cues: cues)
        }

        // MARK: - Block Parsing

        /// Represents the different types of blocks that can appear in a WebVTT file.
        ///
        /// WebVTT files are composed of different block types, each with their own
        /// parsing rules and structure.
        private enum Block {
            /// A region definition block.
            case region(WebVTT.Region)
            /// A CSS style block.
            case style(WebVTT.Style)
            /// A cue block containing timed text.
            case cue(WebVTT.Cue)
            /// A note block (ignored during parsing).
            case note
        }

        /// Parses a single block from the WebVTT content.
        ///
        /// This method identifies the type of block at the current position and
        /// delegates to the appropriate parsing method. It handles the different
        /// block types that can appear in a WebVTT file.
        ///
        /// - Parameters:
        ///   - lines: The lines of WebVTT content.
        ///   - index: The current index in the lines array. This is modified to
        ///     advance past the parsed block.
        /// - Returns: The parsed block, or `nil` if no block was found.
        /// - Throws: `ParseError` if the block cannot be parsed.
        private func parseBlock(from lines: [String], startingAt index: inout Int) throws -> Block?
        {
            // Skip empty lines
            while index < lines.count && lines[index].trimWhitespace().isEmpty {
                index += 1
            }

            guard index < lines.count else { return nil }

            let firstLine = lines[index].trimWhitespace()

            // Check block type
            if firstLine.hasPrefix("REGION") {
                return try .region(parseRegion(from: lines, startingAt: &index))
            } else if firstLine.hasPrefix("STYLE") {
                return try .style(parseStyle(from: lines, startingAt: &index))
            } else if firstLine.hasPrefix("NOTE") {
                parseNote(from: lines, startingAt: &index)
                return .note
            } else if firstLine.contains("-->") {
                // This is a cue with no ID
                return try .cue(parseCue(from: lines, startingAt: &index))
            } else {
                // Could be a cue ID or another cue timing line
                guard index + 1 < lines.count else {
                    // If this looks like a timestamp but has no arrow, it's invalid
                    if firstLine.contains(":") && firstLine.contains(".") {
                        throw WebVTT.ParseError.invalidCueTimings
                    }
                    return nil
                }

                let secondLine = lines[index + 1].trimWhitespace()

                if secondLine.contains("-->") {
                    // First line was cue ID, advance to timing line
                    index += 1
                    return try .cue(parseCueWithId(id: firstLine, from: lines, startingAt: &index))
                } else {
                    // If first line looks like a timestamp but second line has no arrow, it's invalid
                    if firstLine.contains(":") && firstLine.contains(".") {
                        throw WebVTT.ParseError.invalidCueTimings
                    }
                    // Not a valid block, skip it
                    index += 1
                    return nil
                }
            }
        }

        // MARK: - Block-Specific Parsers

        /// Parses a region block from the WebVTT content.
        ///
        /// Region blocks define areas of the video where cues can be displayed.
        /// They contain various settings that control the region's size, position,
        /// and behavior.
        ///
        /// - Parameters:
        ///   - lines: The lines of WebVTT content.
        ///   - index: The current index in the lines array. This is modified to
        ///     advance past the parsed region block.
        /// - Returns: The parsed region.
        /// - Throws: `ParseError` if the region cannot be parsed.
        private func parseRegion(from lines: [String], startingAt index: inout Int) throws
            -> WebVTT.Region
        {
            var region = WebVTT.Region(id: "")
            index += 1  // Skip the "REGION" line

            while index < lines.count {
                let line = lines[index].trimWhitespace()

                if line.isEmpty {
                    index += 1
                    break
                }

                // Parse settings
                // Split by any ASCII whitespace (TAB or SPACE) as per spec, omitting empty subsequences
                let settings = line.splitByASCIIWhitespace()
                for setting in settings {
                    let parts = setting.split(separator: ":", maxSplits: 1)
                    guard parts.count == 2 else { continue }

                    let key = String(parts[0])
                    let value = String(parts[1])

                    switch key {
                    case "id":
                        region.id = value
                    case "width":
                        if let width = parsePercentage(value) {
                            region.width = width
                        }
                    case "lines":
                        if let lines = Int(value) {
                            region.lines = lines
                        }
                    case "regionanchor":
                        if let anchor = parseCoordinates(value) {
                            region.regionAnchor = anchor
                        }
                    case "viewportanchor":
                        if let anchor = parseCoordinates(value) {
                            region.viewportAnchor = anchor
                        }
                    case "scroll":
                        // Accept case-insensitive "up" value, permissive parsing
                        if value.lowercased() == "up" {
                            region.scroll = .up
                        } else {
                            // Invalid value - ignore setting (equivalent to "none")
                            region.scroll = nil
                        }
                    default:
                        break
                    }
                }

                index += 1
            }

            return region
        }

        /// Parses a style block from the WebVTT content.
        ///
        /// Style blocks contain CSS rules that control the appearance of cues
        /// within the video player. The CSS content is preserved as-is and
        /// passed to the video player for interpretation.
        ///
        /// - Parameters:
        ///   - lines: The lines of WebVTT content.
        ///   - index: The current index in the lines array. This is modified to
        ///     advance past the parsed style block.
        /// - Returns: The parsed style block.
        /// - Throws: `ParseError` if the style block cannot be parsed.
        private func parseStyle(from lines: [String], startingAt index: inout Int) throws
            -> WebVTT.Style
        {
            var cssLines: [String] = []
            index += 1  // Skip the "STYLE" line

            while index < lines.count {
                let line = lines[index].trimWhitespace()

                // Check for end of style block (empty line)
                if line.isEmpty {
                    index += 1
                    break
                }

                // Check for cue start (should not happen in style block)
                if line.contains("-->") {
                    break
                }

                // Check for other block headers or cue IDs
                if line.hasPrefix("REGION") || line.hasPrefix("STYLE") || line.hasPrefix("NOTE") {
                    break
                }

                cssLines.append(line)
                index += 1
            }

            return WebVTT.Style(css: cssLines.joined(separator: "\n"))
        }

        /// Parses a note block from the WebVTT content.
        ///
        /// Note blocks are ignored during parsing as they are meant for human
        /// readers and do not affect the functionality of the WebVTT file.
        ///
        /// - Parameters:
        ///   - lines: The lines of WebVTT content.
        ///   - index: The current index in the lines array. This is modified to
        ///     advance past the parsed note block.
        private func parseNote(from lines: [String], startingAt index: inout Int) {
            index += 1  // Skip the "NOTE" line

            while index < lines.count {
                let line = lines[index].trimWhitespace()

                // End of NOTE block: blank line
                if line.isEmpty {
                    index += 1
                    break
                }

                // End if we encounter another block header or cue timing line
                if line.hasPrefix("REGION") || line.hasPrefix("STYLE") || line.hasPrefix("NOTE")
                    || line.contains("-->")
                {
                    break
                }

                index += 1
            }
        }

        // MARK: - Cue Parsing

        /// Parses a cue block from the WebVTT content.
        ///
        /// This method parses a cue that does not have an identifier.
        /// It delegates to the more general `parseCueWithId` method.
        ///
        /// - Parameters:
        ///   - lines: The lines of WebVTT content.
        ///   - index: The current index in the lines array. This is modified to
        ///     advance past the parsed cue block.
        /// - Returns: The parsed cue.
        /// - Throws: `ParseError` if the cue cannot be parsed.
        private func parseCue(from lines: [String], startingAt index: inout Int) throws
            -> WebVTT.Cue
        {
            // Parse timing line
            guard index < lines.count else {
                throw WebVTT.ParseError.invalidCueTimings
            }

            let timingLine = lines[index].trimWhitespace()
            index += 1

            return try parseCueWithId(
                id: nil, timingLine: timingLine, from: lines, startingAt: &index)
        }

        /// Parses a cue block with an identifier from the WebVTT content.
        ///
        /// This method parses a cue that has an identifier on the line before
        /// the timing line. It delegates to the more general `parseCueWithId` method.
        ///
        /// - Parameters:
        ///   - id: The identifier for the cue.
        ///   - lines: The lines of WebVTT content.
        ///   - index: The current index in the lines array. This is modified to
        ///     advance past the parsed cue block.
        /// - Returns: The parsed cue.
        /// - Throws: `ParseError` if the cue cannot be parsed.
        private func parseCueWithId(id: String?, from lines: [String], startingAt index: inout Int)
            throws -> WebVTT.Cue
        {
            guard index < lines.count else {
                throw WebVTT.ParseError.invalidCueTimings
            }

            let timingLine = lines[index].trimWhitespace()
            index += 1

            return try parseCueWithId(
                id: id, timingLine: timingLine, from: lines, startingAt: &index)
        }

        /// Parses a cue block with the specified identifier and timing line.
        ///
        /// This is the main cue parsing method that handles the timing line,
        /// settings, and text content of a cue. It supports both cues with and
        /// without identifiers.
        ///
        /// - Parameters:
        ///   - id: The optional identifier for the cue.
        ///   - timingLine: The timing line containing start and end times.
        ///   - lines: The lines of WebVTT content.
        ///   - index: The current index in the lines array. This is modified to
        ///     advance past the parsed cue block.
        /// - Returns: The parsed cue.
        /// - Throws: `ParseError` if the cue cannot be parsed.
        private func parseCueWithId(
            id: String?, timingLine: String, from lines: [String], startingAt index: inout Int
        ) throws -> WebVTT.Cue {
            // Parse timing and settings
            let components = timingLine.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 3,
                components[1] == "-->"
            else {
                throw WebVTT.ParseError.invalidCueTimings
            }

            guard let startTime = WebVTT.Timestamp.parse(String(components[0])),
                let endTime = WebVTT.Timestamp.parse(String(components[2]))
            else {
                throw WebVTT.ParseError.invalidTimestamp
            }

            var cue = WebVTT.Cue(startTime: startTime, endTime: endTime, text: "")
            cue.id = id

            // Parse settings (everything after the end timestamp)
            if components.count > 3 {
                let settingsString = components[3...].joined(separator: " ")
                cue.settings = parseCueSettings(settingsString)
            }

            // Parse cue text
            var textLines: [String] = []
            while index < lines.count {
                let line = lines[index].trimWhitespace()

                // Check for end of cue (empty line)
                if line.isEmpty {
                    index += 1
                    break
                }

                // Check for next cue or block
                if line.contains("-->") || line.hasPrefix("REGION") || line.hasPrefix("STYLE")
                    || line.hasPrefix("NOTE")
                {
                    break
                }

                textLines.append(line)
                index += 1
            }

            cue.text = textLines.joined(separator: "\n")
            return cue
        }

        // MARK: - Cue Components

        /// Parses cue settings from a settings string.
        ///
        /// Cue settings control the positioning and formatting of cues.
        /// They are specified as space-separated key-value pairs in the
        /// format `key:value`.
        ///
        /// - Parameter string: The settings string to parse.
        /// - Returns: A `Settings` instance containing the parsed settings.
        private func parseCueSettings(_ string: String) -> WebVTT.Cue.Settings {
            var settings = WebVTT.Cue.Settings()
            let components = string.splitByASCIIWhitespace()

            for component in components {
                let parts = component.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { continue }

                let key = String(parts[0])
                let value = String(parts[1])

                switch key {
                case "vertical":
                    settings.vertical = WebVTT.Cue.Settings.WritingDirection(rawValue: value)

                case "line":
                    settings.line = parseLine(value)

                case "position":
                    settings.position = parsePosition(value)

                case "size":
                    if let size = parsePercentage(value) {
                        settings.size = size
                    }

                case "align":
                    settings.align = WebVTT.Cue.Settings.Alignment(rawValue: value)

                case "region":
                    settings.region = value

                case "position-align":
                    if let align = WebVTT.Cue.Settings.Position.PositionAlignment(rawValue: value) {
                        if settings.position == nil {
                            settings.position = WebVTT.Cue.Settings.Position(
                                value: 50, alignment: align)
                        } else {
                            settings.position?.alignment = align
                        }
                    }

                default:
                    break
                }
            }

            return settings
        }

        // MARK: - Settings Parsers

        /// Parses a line setting value.
        ///
        /// Line settings can be specified as percentages, line numbers,
        /// or the keyword "auto". They can also include alignment values.
        ///
        /// - Parameter value: The line setting string to parse.
        /// - Returns: A `Line` instance containing the parsed value.
        private func parseLine(_ value: String) -> WebVTT.Cue.Settings.Line {
            var line = WebVTT.Cue.Settings.Line(value: .auto, alignment: nil)

            let components = value.split(separator: ",")
            if components.isEmpty { return line }

            let lineValue = String(components[0])

            if lineValue == "auto" {
                line.value = .auto
            } else if lineValue.hasSuffix("%") {
                if let percentage = parsePercentage(lineValue) {
                    line.value = .percentage(percentage)
                }
            } else if let number = Int(lineValue) {
                line.value = .lineNumber(number)
            }

            if components.count > 1 {
                line.alignment = WebVTT.Cue.Settings.Line.LineAlignment(
                    rawValue: String(components[1]))
            }

            return line
        }

        /// Parses a position setting value.
        ///
        /// Position settings are specified as percentages with optional
        /// alignment values. They control the horizontal position of cues.
        ///
        /// - Parameter value: The position setting string to parse.
        /// - Returns: A `Position` instance containing the parsed value.
        private func parsePosition(_ value: String) -> WebVTT.Cue.Settings.Position {
            var position = WebVTT.Cue.Settings.Position(value: 50, alignment: nil)

            let components = value.split(separator: ",")
            if components.isEmpty { return position }

            if let percentage = parsePercentage(String(components[0])) {
                position.value = percentage
            }

            if components.count > 1 {
                position.alignment = WebVTT.Cue.Settings.Position.PositionAlignment(
                    rawValue: String(components[1]))
            }

            // Support the single keyword "auto" after the comma as well
            if components.count > 1 && components[1] == "auto" {
                position.alignment = .auto
            }

            return position
        }

        // MARK: - Value Parsers

        /// Parses a percentage value from a string.
        ///
        /// Percentage values must end with a "%" character and contain
        /// a valid numeric value.
        ///
        /// - Parameter string: The percentage string to parse (e.g., "50%").
        /// - Returns: The percentage value as a `Double`, or `nil` if parsing fails.
        private func parsePercentage(_ string: String) -> Double? {
            guard string.hasSuffix("%") else { return nil }
            let numberString = String(string.dropLast())
            return Double(numberString)
        }

        /// Parses coordinate values from a string.
        ///
        /// Coordinate values are specified as two percentage values
        /// separated by a comma (e.g., "50%,100%").
        ///
        /// - Parameter string: The coordinate string to parse.
        /// - Returns: A tuple containing the x and y coordinates, or `nil` if parsing fails.
        private func parseCoordinates(_ string: String) -> (x: Double, y: Double)? {
            let components = string.split(separator: ",")
            guard components.count == 2,
                let x = parsePercentage(String(components[0])),
                let y = parsePercentage(String(components[1]))
            else {
                return nil
            }
            return (x, y)
        }

    }
}

// MARK: - CustomStringConvertible

extension WebVTT.Region: CustomStringConvertible {
    /// Returns a string representation of the region in WebVTT format.
    ///
    /// This method generates the region block content without the "REGION" header
    /// or trailing newline, as those are handled by the main WebVTT description.
    public var description: String {
        var output = "id:\(id)\n"

        if width != 100 {
            output += "width:\(formatPercentage(width))\n"
        }

        if lines != 3 {
            output += "lines:\(lines)\n"
        }

        if regionAnchor != (0, 100) {
            output +=
                "regionanchor:\(formatPercentage(regionAnchor.x)),\(formatPercentage(regionAnchor.y))\n"
        }

        if viewportAnchor != (0, 100) {
            output +=
                "viewportanchor:\(formatPercentage(viewportAnchor.x)),\(formatPercentage(viewportAnchor.y))\n"
        }

        if let scroll = scroll {
            output += "scroll:\(scroll.rawValue)\n"
        }

        return output
    }
}

extension WebVTT.Style: CustomStringConvertible {
    /// Returns a string representation of the style block in WebVTT format.
    ///
    /// This method generates the style block content without the "STYLE" header
    /// or trailing newlines, as those are handled by the main WebVTT description.
    public var description: String {
        return css
    }
}

extension WebVTT.Cue: CustomStringConvertible {
    /// Returns a string representation of the cue in WebVTT format.
    ///
    /// This method generates the complete cue block including ID (if present),
    /// timing line with settings, and text content.
    public var description: String {
        var output = ""

        // Add cue ID if present
        if let id = id {
            output += "\(id)\n"
        }

        // Add timings and settings
        output += "\(startTime.description) --> \(endTime.description)"

        // Add settings
        let settingsString = settings.description
        if !settingsString.isEmpty {
            output += " \(settingsString)"
        }

        output += "\n"

        // Add cue text
        output += text

        return output
    }
}

extension WebVTT.Cue.Settings: CustomStringConvertible {
    /// Returns a string representation of the cue settings in WebVTT format.
    ///
    /// This method generates the settings string that appears after the timing
    /// line in a cue block.
    public var description: String {
        var components: [String] = []

        if let vertical = vertical {
            components.append("vertical:\(vertical.rawValue)")
        }

        if let line = line {
            components.append("line:\(line.description)")
        }

        if let position = position {
            components.append("position:\(position.description)")
        }

        if let size = size {
            components.append("size:\(formatPercentage(size))")
        }

        if let align = align {
            components.append("align:\(align.rawValue)")
        }

        if let region = region {
            components.append("region:\(region)")
        }

        return components.joined(separator: " ")
    }
}

extension WebVTT.Cue.Settings.Line: CustomStringConvertible {
    /// Returns a string representation of the line setting in WebVTT format.
    public var description: String {
        var lineStr = ""

        switch value {
        case .auto:
            lineStr = "auto"
        case .percentage(let value):
            lineStr = formatPercentage(value)
        case .lineNumber(let number):
            lineStr = "\(number)"
        }

        if let alignment = alignment {
            lineStr += ",\(alignment.rawValue)"
        }

        return lineStr
    }
}

extension WebVTT.Cue.Settings.Position: CustomStringConvertible {
    /// Returns a string representation of the position setting in WebVTT format.
    public var description: String {
        var positionStr = formatPercentage(value)

        if let alignment = alignment {
            positionStr += ",\(alignment.rawValue)"
        }

        return positionStr
    }
}

extension WebVTT: CustomStringConvertible {
    /// Returns a string representation of the WebVTT file.
    ///
    /// This method generates a complete WebVTT file in the standard format,
    /// including the signature, regions, styles, and cues. The output follows
    /// the WebVTT specification and can be used directly with video players.
    ///
    /// ## Output Format
    ///
    /// The generated string includes:
    /// - WebVTT signature
    /// - Region definitions (if any)
    /// - Style blocks (if any)
    /// - Cues with timing, settings, and text
    ///
    /// ## Example
    ///
    /// ```swift
    /// let webVTT = WebVTT()
    /// webVTT.cues.append(Cue(
    ///     startTime: Timestamp(minutes: 0, seconds: 5, milliseconds: 0),
    ///     endTime: Timestamp(minutes: 0, seconds: 8, milliseconds: 500),
    ///     text: "Hello, world!"
    /// ))
    ///
    /// print(webVTT.description)
    /// // Output:
    /// // WEBVTT
    /// //
    /// // 00:05.000 --> 00:08.500
    /// // Hello, world!
    /// ```
    public var description: String {
        var output = "WEBVTT\n\n"

        // Generate regions
        for region in regions {
            output += "REGION\n"
            output += region.description
            output += "\n"
        }

        // Generate styles
        for style in styles {
            output += "STYLE\n"
            output += style.description
            output += "\n\n"
        }

        // Generate cues
        for cue in cues {
            output += cue.description
            output += "\n"
        }

        return output
    }
}

// MARK: - Helper Functions

/// Formats a percentage value for WebVTT output.
///
/// This function formats percentage values according to WebVTT conventions:
/// - Integer values are output without decimal places (e.g., "50%")
/// - Non-integer values include decimal places (e.g., "50.5%")
///
/// - Parameter value: The percentage value to format.
/// - Returns: A formatted percentage string.
private func formatPercentage(_ value: Double) -> String {
    return value.truncatingRemainder(dividingBy: 1) == 0
        ? "\(Int(value))%"
        : "\(value)%"
}

// MARK: - Extensions

extension String {
    /// Splits a string by ASCII whitespace characters.
    ///
    /// This method splits the string by space or tab characters and filters out
    /// empty subsequences. It's used for parsing WebVTT settings that are
    /// separated by whitespace.
    ///
    /// - Returns: An array of substrings, excluding empty ones.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let settings = "line:80%,center position:50%"
    /// let components = settings.splitByASCIIWhitespace()
    /// // ["line:80%,center", "position:50%"]
    /// ```
    fileprivate func splitByASCIIWhitespace() -> [Substring] {
        return split(whereSeparator: { $0 == " " || $0 == "\t" }).filter { !$0.isEmpty }
    }

    /// Splits a string by newlines while preserving empty lines.
    ///
    /// This method splits the string by newline characters and preserves
    /// empty lines in the result. It's used for parsing WebVTT content
    /// where empty lines have semantic meaning.
    ///
    /// - Returns: An array of strings, including empty ones.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let content = "WEBVTT\n\n00:00:05.000 --> 00:00:08.000\nHello, world!"
    /// let lines = content.splitByNewlines()
    /// // ["WEBVTT", "", "00:00:05.000 --> 00:00:08.000", "Hello, world!"]
    /// ```
    fileprivate func splitByNewlines() -> [String] {
        return split(omittingEmptySubsequences: false) { character in
            character == "\n" || character == "\r" || character == "\r\n"
        }.map(String.init)
    }

    /// Trims whitespace characters from both ends of the string.
    ///
    /// This method removes space, tab, carriage return, and newline characters
    /// from the beginning and end of the string. It's used for cleaning up
    /// lines during WebVTT parsing.
    ///
    /// - Returns: A new string with leading and trailing whitespace removed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let line = "  \t  Hello, world!  \n  "
    /// let trimmed = line.trimWhitespace()
    /// // "Hello, world!"
    /// ```
    fileprivate func trimWhitespace() -> String {
        let whitespace = Set(" \t\r\n")
        var start = startIndex
        var end = endIndex

        while start < end && whitespace.contains(self[start]) {
            start = index(after: start)
        }

        while end > start && whitespace.contains(self[index(before: end)]) {
            end = index(before: end)
        }

        return String(self[start..<end])
    }
}
