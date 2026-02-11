---
name: iOS Development Helper
description: General instructions and tips for iOS development tasks.
---

# iOS Development Helper

## Adding New Features
1.  **Identify Domain**: Determine if the feature belongs to an existing domain (e.g., `Team`, `Tournament`) or requires a new one.
2.  **Create Files**:
    -   **Model**: Define data structures in `BianLunMiao/Models`.
    -   **ViewModel**: Create logic in `BianLunMiao/ViewModels`.
    -   **View**: Build UI in `BianLunMiao/Views`.
3.  **Update GEMINI.md**: Always update the `GEMINI.md` files at each level (Root, Module, Submodule) to reflect new files.
4.  **Integration**: Add the new View to the appropriate parent View or navigation flow.

## Managing Resources
-   **Images/Colors**: Add to `BianLunMiao/Assets.xcassets`.
-   **Localization**: Use `Localizable.strings` (if applicable).

## Common Patterns
-   **Lists**: Use `List` or `LazyVStack` for collections.
-   **Navigation**: Use `NavigationStack` and `.navigationDestination(for:)`.
-   **Alerts**: Use `.alert(isPresented:content:)` or the custom `ComponentsFeedback` API.

## Troubleshooting
-   **Preview Crashing**: Check for missing `@EnvironmentObject` or crashing code in `init`.
-   **Layout Issues**: Use `Debug View Hierarchy` in Xcode or add `.border(.red)` to views to see frames.
