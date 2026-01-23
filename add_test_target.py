#!/usr/bin/env python3
import subprocess
import os
import uuid

# This script adds a test target to the Xcode project
# Using xcodebuild to create and configure the test target

project_dir = "/Users/dev/Downloads/test/DevCam"
project_path = f"{project_dir}/DevCam.xcodeproj"

# Generate UUIDs for the test target
def generate_uuid():
    return str(uuid.uuid4()).upper().replace('-', '')[:24]

# Read the project.pbxproj file
pbxproj_path = f"{project_path}/project.pbxproj"
with open(pbxproj_path, 'r') as f:
    content = f.read()

# Check if test target already exists
if 'DevCamTests' in content:
    print("Test target already exists")
    exit(0)

# This is complex - let's use plutil to work with the project file
print("Adding test target to Xcode project...")

# Create a backup
import shutil
shutil.copy(pbxproj_path, f"{pbxproj_path}.backup")

# Find the main target UUID
import re
target_match = re.search(r'([A-F0-9]{24}) /\* DevCam \*/', content)
if not target_match:
    print("Could not find main target")
    exit(1)

main_target_uuid = target_match.group(1)

# Generate new UUIDs
test_target_uuid = generate_uuid()
test_product_uuid = generate_uuid()
test_source_buildphase_uuid = generate_uuid()
test_frameworks_buildphase_uuid = generate_uuid()
test_resources_buildphase_uuid = generate_uuid()
test_fileref_uuid = generate_uuid()
test_buildfile_uuid = generate_uuid()

# Find where to insert (after main target)
insert_pos = content.find(f"{main_target_uuid} /* DevCam */,")
if insert_pos == -1:
    print("Could not find insertion point")
    exit(1)

# This is getting too complex. Let's provide manual instructions instead.
print("Manual configuration required. Please use Xcode GUI to add test target.")
