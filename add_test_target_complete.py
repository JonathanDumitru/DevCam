#!/usr/bin/env python3
import re
import uuid

def generate_uuid():
    """Generate a 24-character hex UUID similar to Xcode's format"""
    return uuid.uuid4().hex[:24].upper()

# Read the project file
project_path = "/Users/dev/Downloads/test/DevCam/DevCam.xcodeproj/project.pbxproj"
with open(project_path, 'r') as f:
    content = f.read()

# Check if test target already exists
if 'DevCamTests' in content:
    print("Test target already exists!")
    exit(0)

# Generate UUIDs for new elements
test_target_uuid = generate_uuid()
test_product_uuid = generate_uuid()
test_sources_uuid = generate_uuid()
test_frameworks_uuid = generate_uuid()
test_resources_uuid = generate_uuid()
test_buildconfig_list_uuid = generate_uuid()
test_debug_config_uuid = generate_uuid()
test_release_config_uuid = generate_uuid()
test_dependency_uuid = generate_uuid()
test_target_dependency_uuid = generate_uuid()
test_group_uuid = generate_uuid()

# 1. Add test product to PBXFileReference section
file_ref_section = re.search(r'/\* Begin PBXFileReference section \*/\n(.*?)\n/\* End PBXFileReference section \*/', content, re.DOTALL)
if file_ref_section:
    new_file_ref = f'\t\t{test_product_uuid} /* DevCamTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = DevCamTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};\n'
    content = content.replace(
        '/* End PBXFileReference section */',
        new_file_ref + '/* End PBXFileReference section */'
    )

# 2. Add test group to PBXFileSystemSynchronizedRootGroup section
fs_sync_section = re.search(r'/\* End PBXFileSystemSynchronizedRootGroup section \*/', content)
if fs_sync_section:
    new_group = f'''\t\t{test_group_uuid} /* DevCamTests */ = {{
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\tpath = DevCamTests;
\t\t\tsourceTree = "<group>";
\t\t}};
'''
    content = content.replace(
        '/* End PBXFileSystemSynchronizedRootGroup section */',
        new_group + '/* End PBXFileSystemSynchronizedRootGroup section */'
    )

# 3. Add frameworks build phase
frameworks_section = re.search(r'/\* End PBXFrameworksBuildPhase section \*/', content)
if frameworks_section:
    new_frameworks = f'''\t\t{test_frameworks_uuid} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
'''
    content = content.replace(
        '/* End PBXFrameworksBuildPhase section */',
        new_frameworks + '/* End PBXFrameworksBuildPhase section */'
    )

# 4. Add test product to Products group
products_group = re.search(r'(D76E4B1F2F2331380090999D /\* Products \*/ = \{.*?children = \(\s*)(.*?)(\s*\);)', content, re.DOTALL)
if products_group:
    existing_children = products_group.group(2)
    new_children = existing_children + f'\t\t\t\t{test_product_uuid} /* DevCamTests.xctest */,\n'
    content = content.replace(
        products_group.group(0),
        products_group.group(1) + new_children + products_group.group(3)
    )

# 5. Add test group to main group
main_group = re.search(r'(D76E4B152F2331380090999D = \{.*?children = \(\s*)(.*?)(\s*\);)', content, re.DOTALL)
if main_group:
    existing_children = main_group.group(2)
    new_children = existing_children + f'\t\t\t\t{test_group_uuid} /* DevCamTests */,\n'
    content = content.replace(
        main_group.group(0),
        main_group.group(1) + new_children + main_group.group(3)
    )

# 6. Add test target to PBXNativeTarget section
native_target_section = re.search(r'/\* End PBXNativeTarget section \*/', content)
if native_target_section:
    new_target = f'''\t\t{test_target_uuid} /* DevCamTests */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {test_buildconfig_list_uuid} /* Build configuration list for PBXNativeTarget "DevCamTests" */;
\t\t\tbuildPhases = (
\t\t\t\t{test_sources_uuid} /* Sources */,
\t\t\t\t{test_frameworks_uuid} /* Frameworks */,
\t\t\t\t{test_resources_uuid} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{test_dependency_uuid} /* PBXTargetDependency */,
\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t{test_group_uuid} /* DevCamTests */,
\t\t\t);
\t\t\tname = DevCamTests;
\t\t\tpackageProductDependencies = (
\t\t\t);
\t\t\tproductName = DevCamTests;
\t\t\tproductReference = {test_product_uuid} /* DevCamTests.xctest */;
\t\t\tproductType = "com.apple.product-type.bundle.unit-test";
\t\t}};
'''
    content = content.replace(
        '/* End PBXNativeTarget section */',
        new_target + '/* End PBXNativeTarget section */'
    )

# 7. Add PBXContainerItemProxy section if it doesn't exist
if '/* Begin PBXContainerItemProxy section */' not in content:
    container_proxy = f'''/* Begin PBXContainerItemProxy section */
\t\t{test_target_dependency_uuid} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = D76E4B162F2331380090999D /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = D76E4B1D2F2331380090999D;
\t\t\tremoteInfo = DevCam;
\t\t}};
/* End PBXContainerItemProxy section */

'''
    content = content.replace(
        '/* Begin PBXFileReference section */',
        container_proxy + '/* Begin PBXFileReference section */'
    )

# 8. Add PBXTargetDependency section if it doesn't exist
if '/* Begin PBXTargetDependency section */' not in content:
    target_dependency = f'''/* Begin PBXTargetDependency section */
\t\t{test_dependency_uuid} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = D76E4B1D2F2331380090999D /* DevCam */;
\t\t\ttargetProxy = {test_target_dependency_uuid} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */

'''
    content = content.replace(
        '/* Begin PBXFrameworksBuildPhase section */',
        target_dependency + '/* Begin PBXFrameworksBuildPhase section */'
    )

# 9. Add test target to project targets list
targets_list = re.search(r'(targets = \(\s*)(.*?)(\s*\);)', content, re.DOTALL)
if targets_list:
    existing_targets = targets_list.group(2)
    new_targets = existing_targets + f'\t\t\t\t{test_target_uuid} /* DevCamTests */,\n'
    content = content.replace(
        targets_list.group(0),
        targets_list.group(1) + new_targets + targets_list.group(3)
    )

# 10. Add test target attributes
target_attrs = re.search(r'(TargetAttributes = \{)(.*?)(\s*\};)', content, re.DOTALL)
if target_attrs:
    existing_attrs = target_attrs.group(2)
    new_attrs = existing_attrs + f'''
\t\t\t\t\t{test_target_uuid} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 26.2;
\t\t\t\t\t\tTestTargetID = D76E4B1D2F2331380090999D;
\t\t\t\t\t}};'''
    content = content.replace(
        target_attrs.group(0),
        target_attrs.group(1) + new_attrs + target_attrs.group(3)
    )

# 11. Add Resources build phase
resources_section = re.search(r'/\* End PBXResourcesBuildPhase section \*/', content)
if resources_section:
    new_resources = f'''\t\t{test_resources_uuid} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
'''
    content = content.replace(
        '/* End PBXResourcesBuildPhase section */',
        new_resources + '/* End PBXResourcesBuildPhase section */'
    )

# 12. Add Sources build phase
sources_section = re.search(r'/\* End PBXSourcesBuildPhase section \*/', content)
if sources_section:
    new_sources = f'''\t\t{test_sources_uuid} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
'''
    content = content.replace(
        '/* End PBXSourcesBuildPhase section */',
        new_sources + '/* End PBXSourcesBuildPhase section */'
    )

# 13. Add build configurations for test target
build_config_section = re.search(r'/\* End XCBuildConfiguration section \*/', content)
if build_config_section:
    new_debug_config = f'''\t\t{test_debug_config_uuid} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = 93QQU293YD;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "Jonathan-Hines-Dumitru.DevCamTests";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/DevCam.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/DevCam";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{test_release_config_uuid} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = 93QQU293YD;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "Jonathan-Hines-Dumitru.DevCamTests";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/DevCam.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/DevCam";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
'''
    content = content.replace(
        '/* End XCBuildConfiguration section */',
        new_debug_config + '/* End XCBuildConfiguration section */'
    )

# 14. Add build configuration list for test target
config_list_section = re.search(r'/\* End XCConfigurationList section \*/', content)
if config_list_section:
    new_config_list = f'''\t\t{test_buildconfig_list_uuid} /* Build configuration list for PBXNativeTarget "DevCamTests" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{test_debug_config_uuid} /* Debug */,
\t\t\t\t{test_release_config_uuid} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
'''
    content = content.replace(
        '/* End XCConfigurationList section */',
        new_config_list + '/* End XCConfigurationList section */'
    )

# Write the modified content back
with open(project_path, 'w') as f:
    f.write(content)

print("Successfully added DevCamTests target to Xcode project!")
