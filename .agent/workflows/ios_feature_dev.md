---
description: A workflow for developing and verifying iOS features.
---

# iOS Feature Development Workflow

1.  **Understand the Goal**
    -   Analyze the user request.
    -   Consult `GEMINI.md` to understand the current architecture and file structure.
    -   Identify necessary changes (Models, ViewModels, Views).

2.  **Plan the Changes**
    -   Create a checklist of files to modify or create.
    -   Ensure the plan adheres to `mvvm_architecture` and `swift_standards` skills.

3.  **Implement Changes**
    -   Apply changes to the codebase.
    -   Update `GEMINI.md` (and sub-modules) if files are added/removed.

4.  **Verify Build**
    -   Run the `xcode_build_agent` skill to build the project.
    -   If build fails:
        -   Analyze the error log.
        -   Fix the issue.
        -   Repeat Step 4.

5.  **Verify Functionality (Manual/Mental)**
    -   Review the code logic.
    -   Ensure UI components are correctly hooked up to ViewModels.

6.  **Notify User**
    -   Report success.
    -   Provide a summary of changes.
