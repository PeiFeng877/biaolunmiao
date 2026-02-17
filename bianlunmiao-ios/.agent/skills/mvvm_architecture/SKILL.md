---
name: MVVM Architecture
description: Guidelines for implementing the Model-View-ViewModel architecture in SwiftUI.
---

# MVVM Architecture Guidelines

This project follows a strict Model-View-ViewModel (MVVM) architecture with SwiftUI.

## Core Components

### 1. Model
- **Location**: `BianLunMiao/Models`
- **Responsibility**: pure data structures (structs, enums).
- **Constraints**:
    - **NO** SwiftUI imports.
    - **NO** business logic beyond simple computed properties.
    - Must be `Codable` where applicable.

### 2. ViewModel
- **Location**: `BianLunMiao/ViewModels`
- **Responsibility**:
    - Transforming Model data into View state.
    - Handling user intents (functions called by View).
    - Communicating with the Data Layer (`AppStore` or Services).
- **Constraints**:
    - Must verify `MainActor` for UI updates.
    - Should expose `Published` properties for View consumption.
    - **NO** direct View references (e.g., `SwiftUI.View`).

### 3. View
- **Location**: `BianLunMiao/Views`
- **Responsibility**:
    - Declaring the UI structure.
    - Rendering state from the ViewModel.
    - Forwarding user actions to the ViewModel.
- **Constraints**:
    - **NO** complex business logic.
    - Use `DesignSystem` components primarily.
    - Avoid hardcoded colors/dimensions.

### 4. Data Layer (AppStore)
- **Location**: `BianLunMiao/Data`
- **Responsibility**:
    - Maintaining global app state.
    - Networking and Persistence.
- **Usage**:
    - ViewModels inject or access the `AppStore`.

## Implementation Rules

1.  **One ViewModel per Screen**: Complex screens should have a dedicated ViewModel.
2.  **State Observation**: Use `@StateObject` for owning a ViewModel, `@ObservedObject` for passing it down.
3.  **Dependency Injection**: Initialize ViewModels with necessary data or services, don't rely on global singletons inside the ViewModel if possible (though `AppStore.shared` pattern is acceptable if consistent).
