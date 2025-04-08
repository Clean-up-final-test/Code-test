# Project Build Fix

## Problem
The Xcode project has been experiencing "Multiple commands produce the same output file" errors during build. This happens because the project's "File System Synchronized Groups" feature is including both versions of certain Swift files:

1. Original files in subdirectories (`iOS/Views/Settings/About/` and `iOS/Views/Settings/AI Learning/`)
2. Duplicate files we created directly in `iOS/Views/Settings/`

## Solution
We've implemented a two-part solution:

### 1. Duplicate Files in the Settings Directory
We've created copies of these files directly in the Settings directory:
- `SettingsHeaderTableViewCell.swift`
- `AILearningSettingsViewController.swift`
- `ImprovedLearningSettingsCell.swift`
- `ImprovedLearningViewController.swift`
- `ModelServerIntegrationViewController.swift`

### 2. GitHub Workflow to Fix Project File
We've created a GitHub workflow that automatically updates the project.pbxproj file to exclude these files from automatic synchronization. This prevents the "Multiple commands produce" errors by ensuring only one version of each file is included in the build.

The workflow adds these files to the project's membership exceptions:
```
SettingsHeaderTableViewCell.swift,
AILearningSettingsViewController.swift,
ImprovedLearningSettingsCell.swift,
ImprovedLearningViewController.swift,
ModelServerIntegrationViewController.swift,
```

## How It Works
1. Our GitHub workflow runs `scripts/ci/fix-project.sh` before each build
2. The script modifies the project.pbxproj file to add the duplicate files to the exception list
3. This ensures only one version of each file is included in the build process
4. The changes are committed back to the repository if needed

## For Developers
If you make changes to any of these files, please update both the original file and the copy in the Settings directory until a more permanent solution is implemented.

## Long-Term Solution
A proper fix would involve updating the Xcode project directly to organize files correctly and remove the need for duplicates. This would require:
1. Opening the project in Xcode
2. Adjusting file references to point to the actual locations
3. Removing the duplication mechanism
