Keep answers short unless otherwise requested. Be direct and unsparing.

Do not run visual simulator checks for non-UI changes. For persistence,
domain logic, settings defaults, migrations, and other non-visual code paths,
prefer focused unit tests or build checks. Use simulator UI or screenshot
verification only when the change affects visible UI, navigation, layout,
rendering, or user interaction.

Write all new tests using Swift Testing (`import Testing`, `@Test`, `#expect`,
and `#require`). Do not add new XCTest-based tests. Existing XCTest tests may
remain, but when modifying a test file, migrate the affected tests to Swift
Testing when practical.

For command-line Xcode verification, use `.build/DerivedData` so builds stay
inside the workspace sandbox. Keep `.build/DerivedData/` ignored, and do not
add Xcode build output to git.
