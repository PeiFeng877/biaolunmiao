---
name: Swift Standards
description: Coding standards and best practices for Swift development.
---

# Swift Coding Standards

## General Guidelines

### 1. Concurrency
- Prefer Structured Concurrency (`async`/`await`) over completion handlers or Combine (unless interacting with specific Combine-based APIs).
- Use `Task { ... }` for launching async work from synchronous contexts (e.g., SwiftUI views).
- Use `@MainActor` for ViewModels and UI-related classes.

### 2. Naming Conventions
- Types: `UpperCamelCase` (e.g., `TournamentDetailView`).
- Properties/Functions: `lowerCamelCase` (e.g., `fetchData()`).
- Bool Properties: Should read like a question or assertion (e.g., `isLoading`, `hasError`, `canSubmit`).

### 3. File Organization
- Imports: Group system frameworks first, then 3rd party, then internal modules.
- Extensions: Use extensions to group protocol conformances or functionality chunks.
- MARK Comments: Use `// MARK: - Section Name` to organize code sections.

### 4. Safety
- Avoid Force Unwrapping (`!`). Use `if let`, `guard let`, or nil-coalescing (`??`) instead.
- Handle errors gracefully. Don't ignore `try?` unless failure is truly inconsequential.

## SwiftUI Specifics

### 1. View Body
- Keep `body` properties clean. Extract complex view logic into subviews or `@ViewBuilder` functions.
- Avoid side effects directly in `body`. Use `.onAppear`, `.task`, or `.onChange`.

### 2. Modifiers
- Chain modifiers consistently.
- Create custom ViewModifiers for reusable styling.

### 3. State Management
- Use `@State` for private, view-local state.
- Use `@Binding` for passing state write access to child views.
- Use `@EnvironmentObject` sparingly; prefer passing data explicitly via init or `@ObservedObject`.

## Testing
- Write Unit Tests for ViewModels and Business Logic.
- Write UI Tests for critical user flows.
