#!/bin/bash

# Script to fix the project file to avoid "Multiple commands produce" errors

# Ensure we're in the repo root
cd "$(git rev-parse --show-toplevel)" || exit 1

# Define the fixed text to add to the exception list
FIXED_TEXT='SettingsHeaderTableViewCell.swift,\
AILearningSettingsViewController.swift,\
ImprovedLearningSettingsCell.swift,\
ImprovedLearningViewController.swift,\
ModelServerIntegrationViewController.swift,'

# Find the line to modify (after "Info.plist,")
LINE_NUM=$(grep -n "Info.plist," backdoor.xcodeproj/project.pbxproj | head -1 | cut -d: -f1)

if [ -z "$LINE_NUM" ]; then
  echo "Error: Could not find 'Info.plist,' line in project file"
  exit 1
fi

# Insert the fixed text after the Info.plist line
sed -i "${LINE_NUM}a\\${FIXED_TEXT}" backdoor.xcodeproj/project.pbxproj

echo "Project file successfully patched"
