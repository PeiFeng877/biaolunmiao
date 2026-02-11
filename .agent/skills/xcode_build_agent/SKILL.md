---
name: Xcode Build Agent
description: Instructions for building, testing, and debugging iOS projects using xcodebuild.
---

# Xcode Build Agent Instructions

## Overview
This skill provides the capabilities to build, test, and analyze the iOS project using `xcodebuild`.

## Commands

### 1. Build Project
To build the project for the iOS Simulator:
```bash
xcodebuild build \
  -scheme BianLunMiao \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  | xcbeautify
```
*Note: If `xcbeautify` is not available, use raw output or `cat`.*

### 2. Run Tests
To run unit and UI tests:
```bash
xcodebuild test \
  -scheme BianLunMiao \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### 3. Clean Project
```bash
xcodebuild clean -scheme BianLunMiao
```

## Debugging and Error Analysis

When a build fails:
1.  **Capture Output**: Run the build command and capture the output.
2.  **Scan for Errors**: Look for lines starting with `error:` or `fatal error:`.
    - *Example*: `error: expected '}' at end of brace statement`
3.  **Locate File**: Identify the file path and line number associated with the error.
4.  **Analyze Context**: Read the code around the error line.
5.  **Fix and Retry**: Apply the fix and run the build command again.

## Continuous Integration Workflow
1.  Make code changes.
2.  Run `xcodebuild build`.
3.  If success -> Done.
4.  If failure -> Analyze log -> Fix code -> Goto 2.
