#!/usr/bin/env bash
# ==============================================================================
# Namaz Vakti — Local Pre-Flight Release Verification Script
# ==============================================================================
# Usage:
#   ./scripts/release-check.sh                 # Full check (files + Android + iOS)
#   ./scripts/release-check.sh --files-only    # Verify required files & config only
#   ./scripts/release-check.sh --android-only  # Verify files + Android tests/builds
#   ./scripts/release-check.sh --ios-only      # Verify files + iOS XcodeGen/build/tests
#   ./scripts/release-check.sh --skip-tests    # Run builds without unit test suites
# ==============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RUN_ANDROID=true
RUN_IOS=true
RUN_TESTS=true

for arg in "$@"; do
  case "$arg" in
    --files-only)
      RUN_ANDROID=false
      RUN_IOS=false
      ;;
    --android-only)
      RUN_ANDROID=true
      RUN_IOS=false
      ;;
    --ios-only)
      RUN_ANDROID=false
      RUN_IOS=true
      ;;
    --skip-tests)
      RUN_TESTS=false
      ;;
    -h|--help)
      sed -n '2,12p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Run './scripts/release-check.sh --help' for usage."
      exit 1
      ;;
  esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

log_section() {
  echo ""
  echo -e "${BLUE}======================================================================${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}======================================================================${NC}"
}

log_pass() {
  echo -e "  ${GREEN}[PASS]${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

log_warn() {
  echo -e "  ${YELLOW}[WARN]${NC} $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

log_fail() {
  echo -e "  ${RED}[FAIL]${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# ------------------------------------------------------------------------------
# 1. Required Release & CI/CD Files Verification
# ------------------------------------------------------------------------------
log_section "1. Checking Required Repository & Release Files"

REQUIRED_FILES=(
  "GEMINI.md"
  "RELEASE_GUIDE.md"
  "scripts/release-check.sh"
  "scripts/ios-testflight.sh"
  ".github/workflows/ci.yml"
  ".github/workflows/ios-testflight.yml"
  ".github/workflows/android-playstore.yml"
  "android/build.gradle.kts"
  "android/app/build.gradle.kts"
  "android/app/proguard-rules.pro"
  "android/app/src/main/AndroidManifest.xml"
  "ios/project.yml"
  "ios/NamazVakti/NamazVakti/Info.plist"
  "ios/NamazVakti/NamazVakti/PrivacyInfo.xcprivacy"
  "ios/NamazVakti/NamazVakti/NamazVakti.entitlements"
  "ios/NamazVaktiWidget/Info.plist"
  "ios/NamazVaktiWidget/NamazVaktiWidget.entitlements"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [ -f "$ROOT_DIR/$file" ]; then
    log_pass "Found required file: $file"
  else
    log_fail "Missing required file: $file"
  fi
done

OPTIONAL_RELEASE_FILES=(
  "ios/ExportOptions.plist"
  "ios/fastlane/Fastfile"
  "android/fastlane/Fastfile"
  "ios/NamazVakti/NamazVakti/GoogleService-Info.plist"
)

for file in "${OPTIONAL_RELEASE_FILES[@]}"; do
  if [ -f "$ROOT_DIR/$file" ]; then
    log_pass "Found release config/asset: $file"
  else
    log_warn "Optional release file not present yet: $file"
  fi
done

if [ -f "$ROOT_DIR/android/keystore.properties" ] || [ -n "${ANDROID_KEYSTORE_PATH:-}" ]; then
  log_pass "Android release signing credentials detected (keystore.properties or ANDROID_KEYSTORE_PATH)"
else
  log_warn "No local Android keystore configured (android/keystore.properties or ANDROID_KEYSTORE_PATH). CI will use GitHub Secrets."
fi

# ------------------------------------------------------------------------------
# 2. Bundle IDs, App Group, Privacy Manifest & Version Alignment Check
# ------------------------------------------------------------------------------
log_section "2. Verifying Bundle IDs, Privacy Compliance & Version Alignment"

# Check Android applicationId
if grep -q 'applicationId = "com.oktay.namaz"' "$ROOT_DIR/android/app/build.gradle.kts"; then
  log_pass "Android applicationId is 'com.oktay.namaz'"
else
  log_fail "Android applicationId mismatch in android/app/build.gradle.kts"
fi

# Check iOS bundleIdPrefix and Widget bundle ID
if grep -q "bundleIdPrefix: com.okib" "$ROOT_DIR/ios/project.yml" && \
   grep -q "PRODUCT_BUNDLE_IDENTIFIER: com.okib.NamazVakti.NamazVaktiWidget" "$ROOT_DIR/ios/project.yml"; then
  log_pass "iOS bundle identifiers match 'com.okib.NamazVakti' and 'com.okib.NamazVakti.NamazVaktiWidget'"
else
  log_fail "iOS bundle identifiers mismatch in ios/project.yml"
fi

# Check iOS App Group in both entitlements
if grep -q "group.com.okib.namaz" "$ROOT_DIR/ios/NamazVakti/NamazVakti/NamazVakti.entitlements" && \
   grep -q "group.com.okib.namaz" "$ROOT_DIR/ios/NamazVaktiWidget/NamazVaktiWidget.entitlements"; then
  log_pass "App Group 'group.com.okib.namaz' is configured in both App and Widget entitlements"
else
  log_fail "App Group 'group.com.okib.namaz' missing from entitlements"
fi

# Check iOS PrivacyInfo.xcprivacy for CA92.1
if grep -q "NSPrivacyAccessedAPICategoryUserDefaults" "$ROOT_DIR/ios/NamazVakti/NamazVakti/PrivacyInfo.xcprivacy" && \
   grep -q "CA92.1" "$ROOT_DIR/ios/NamazVakti/NamazVakti/PrivacyInfo.xcprivacy"; then
  log_pass "PrivacyInfo.xcprivacy declares NSPrivacyAccessedAPICategoryUserDefaults with reason CA92.1"
else
  log_fail "PrivacyInfo.xcprivacy missing NSPrivacyAccessedAPICategoryUserDefaults or CA92.1"
fi

# Extract versions (supports both literal versionName = "1.0.0" and resolvedVersionName ?: "1.0.0")
ANDROID_VERSION_NAME=$(python3 -c '
import re
text = open("android/app/build.gradle.kts", encoding="utf-8").read()
m = re.search(r"resolvedVersionName\s*=.*?\"([0-9]+\.[0-9]+(?:\.[0-9]+)?)\"", text, re.S) or \
    re.search(r"versionName\s*=\s*\"([^\"]+)\"", text)
print(m.group(1) if m else "unknown")
')
ANDROID_VERSION_CODE=$(python3 -c '
import re
text = open("android/app/build.gradle.kts", encoding="utf-8").read()
m = re.search(r"resolvedVersionCode\s*=.*?\?:\s*([0-9]+)", text, re.S) or \
    re.search(r"versionCode\s*=\s*([0-9]+)", text)
print(m.group(1) if m else "unknown")
')
IOS_MARKETING_VERSION=$(grep -E 'MARKETING_VERSION:' "$ROOT_DIR/ios/project.yml" | head -n1 | awk '{print $2}' | tr -d '"'\''' || echo "unknown")
IOS_BUILD_NUMBER=$(grep -E 'CURRENT_PROJECT_VERSION:' "$ROOT_DIR/ios/project.yml" | head -n1 | awk '{print $2}' | tr -d '"'\''' || echo "unknown")

echo ""
echo "  Platform Version Summary:"
echo "  -------------------------"
echo "  Android : versionName=${ANDROID_VERSION_NAME} (versionCode=${ANDROID_VERSION_CODE})"
echo "  iOS     : MARKETING_VERSION=${IOS_MARKETING_VERSION} (CURRENT_PROJECT_VERSION=${IOS_BUILD_NUMBER})"
echo ""

if [ "$ANDROID_VERSION_NAME" = "$IOS_MARKETING_VERSION" ]; then
  log_pass "Marketing versions are aligned across Android and iOS (${ANDROID_VERSION_NAME})"
else
  log_warn "Marketing version mismatch: Android (${ANDROID_VERSION_NAME}) vs iOS (${IOS_MARKETING_VERSION})"
fi

# ------------------------------------------------------------------------------
# 3. Android Verification (Unit Tests + Debug & Release Build Checks)
# ------------------------------------------------------------------------------
if [ "$RUN_ANDROID" = true ]; then
  log_section "3. Running Android Pre-Flight Checks"

  if ! command -v java >/dev/null 2>&1; then
    log_fail "Java runtime not found. Install JDK 17+ to build Android."
  else
    pushd "$ROOT_DIR/android" >/dev/null
    chmod +x ./gradlew

    if [ "$RUN_TESTS" = true ]; then
      echo "  -> Running ./gradlew testDebugUnitTest..."
      if ./gradlew testDebugUnitTest; then
        log_pass "Android unit tests (testDebugUnitTest) passed"
      else
        log_fail "Android unit tests (testDebugUnitTest) failed"
      fi
    fi

    echo "  -> Running ./gradlew assembleDebug..."
    if ./gradlew assembleDebug; then
      log_pass "Android debug APK build (assembleDebug) succeeded"
    else
      log_fail "Android debug APK build (assembleDebug) failed"
    fi

    echo "  -> Running ./gradlew assembleRelease..."
    if ./gradlew assembleRelease; then
      log_pass "Android release build (assembleRelease) succeeded"
    else
      log_fail "Android release build (assembleRelease) failed"
    fi

    popd >/dev/null
  fi
fi

# ------------------------------------------------------------------------------
# 4. iOS Verification (XcodeGen + Simulator Build & Tests)
# ------------------------------------------------------------------------------
if [ "$RUN_IOS" = true ]; then
  log_section "4. Running iOS Pre-Flight Checks"

  if [ "$(uname -s)" != "Darwin" ]; then
    log_warn "Skipping iOS build verification (macOS required)"
  else
    if ! command -v xcodegen >/dev/null 2>&1; then
      log_fail "xcodegen is not installed. Run 'brew install xcodegen'."
    else
      pushd "$ROOT_DIR/ios" >/dev/null

      echo "  -> Regenerating NamazVakti.xcodeproj with xcodegen..."
      if xcodegen generate; then
        log_pass "XcodeGen project generation succeeded"
      else
        log_fail "XcodeGen project generation failed"
      fi

      SIM_UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
data = json.load(sys.stdin).get("devices", {})
candidates = []
for runtime, devices in data.items():
    if "iOS" not in runtime:
        continue
    for d in devices:
        if d.get("isAvailable") and "iPhone" in d.get("name", ""):
            candidates.append((runtime, d["name"], d["udid"]))
candidates.sort(key=lambda x: (x[0], "Pro" in x[1], "16" in x[1] or "15" in x[1]), reverse=True)
print(candidates[0][2] if candidates else "")
' || echo "")

      if [ -z "$SIM_UDID" ]; then
        log_fail "No available iPhone simulator found via xcrun simctl"
      else
        echo "  -> Building NamazVakti for iOS Simulator (UDID: $SIM_UDID)..."
        if xcodebuild build \
          -project NamazVakti.xcodeproj \
          -scheme NamazVakti \
          -sdk iphonesimulator \
          -destination "platform=iOS Simulator,id=$SIM_UDID" \
          CODE_SIGNING_ALLOWED=NO \
          COMPILER_INDEX_STORE_ENABLE=NO \
          -quiet; then
          log_pass "iOS Simulator build succeeded"
        else
          log_fail "iOS Simulator build failed"
        fi

        if [ "$RUN_TESTS" = true ] && grep -q "type: bundle.unit-test" "$ROOT_DIR/ios/project.yml"; then
          echo "  -> Running iOS unit tests on Simulator (UDID: $SIM_UDID)..."
          if xcodebuild test \
            -project NamazVakti.xcodeproj \
            -scheme NamazVakti \
            -sdk iphonesimulator \
            -destination "platform=iOS Simulator,id=$SIM_UDID" \
            CODE_SIGNING_ALLOWED=NO \
            COMPILER_INDEX_STORE_ENABLE=NO \
            -quiet; then
            log_pass "iOS Simulator unit tests passed"
          else
            log_fail "iOS Simulator unit tests failed"
          fi
        fi
      fi

      popd >/dev/null
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 5. Summary Report
# ------------------------------------------------------------------------------
log_section "Pre-Flight Verification Summary"
echo -e "  Passed   : ${GREEN}${PASS_COUNT}${NC}"
echo -e "  Warnings : ${YELLOW}${WARN_COUNT}${NC}"
echo -e "  Failures : ${RED}${FAIL_COUNT}${NC}"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}Release check FAILED with ${FAIL_COUNT} error(s). Please fix them before tagging a release.${NC}"
  exit 1
fi

echo -e "${GREEN}All pre-flight checks PASSED! Ready to tag and publish:${NC}"
echo "  • Local iOS TestFlight : ./scripts/ios-testflight.sh --version ${IOS_MARKETING_VERSION} --build ${IOS_BUILD_NUMBER}"
echo "  • CI iOS TestFlight    : git tag -a v${IOS_MARKETING_VERSION} -m \"iOS Release v${IOS_MARKETING_VERSION}\" && git push origin v${IOS_MARKETING_VERSION}"
echo "  • CI Android PlayStore : git tag -a android-v${ANDROID_VERSION_NAME} -m \"Android Release v${ANDROID_VERSION_NAME}\" && git push origin android-v${ANDROID_VERSION_NAME}"
