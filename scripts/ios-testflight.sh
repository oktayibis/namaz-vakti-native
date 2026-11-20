#!/usr/bin/env bash
# ==============================================================================
# Namaz Vakti — Turnkey Local iOS TestFlight Archive & Upload Script
# ==============================================================================
# Builds, signs (via Xcode Automatic Provisioning + App Store Connect API Key),
# exports NamazVakti.ipa, and uploads directly to Apple TestFlight.
#
# No manual .mobileprovision downloads required! Xcode automatically creates and
# updates the App Store profiles for both com.okib.NamazVakti and
# com.okib.NamazVakti.NamazVaktiWidget using -allowProvisioningUpdates.
#
# Usage:
#   ./scripts/ios-testflight.sh [options]
#
# Options:
#   --version <X.Y.Z>     Override MARKETING_VERSION (defaults to ios/project.yml)
#   --build <N>           Override CURRENT_PROJECT_VERSION (defaults to ios/project.yml)
#   --archive-only        Build .xcarchive and export signed .ipa without uploading
#   --env-file <path>     Path to .env file (defaults to ios/.env if present)
#   -h, --help            Show this help message
#
# Environment Variables (via shell or ios/.env):
#   APPLE_TEAM_ID                      (Required; defaults to team in ios/project.yml)
#   APP_STORE_CONNECT_API_KEY_ID       (or ASC_KEY_ID)
#   APP_STORE_CONNECT_ISSUER_ID        (or ASC_ISSUER_ID)
#   APP_STORE_CONNECT_API_KEY_PATH     (Path to AuthKey_<KEY_ID>.p8)
#   APP_STORE_CONNECT_API_KEY_BASE64   (Alternative: Base64-encoded .p8 content)
# ==============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"
ENV_FILE="$IOS_DIR/.env"

ARG_VERSION=""
ARG_BUILD=""
ARCHIVE_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      ARG_VERSION="${2:-}"
      shift 2
      ;;
    --build)
      ARG_BUILD="${2:-}"
      shift 2
      ;;
    --archive-only)
      ARCHIVE_ONLY=true
      shift
      ;;
    --env-file)
      ENV_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      sed -n '2,29p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Run './scripts/ios-testflight.sh --help' for usage."
      exit 1
      ;;
  esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  log_error "iOS archiving requires macOS with Xcode installed."
  exit 1
fi

# ------------------------------------------------------------------------------
# 1. Load Credentials from ios/.env (if present) and Environment
# ------------------------------------------------------------------------------
if [[ -f "$ENV_FILE" ]]; then
  log_info "Loading credentials from $ENV_FILE"
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
elif [[ -f "$ROOT_DIR/.env" ]]; then
  log_info "Loading credentials from $ROOT_DIR/.env"
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.env"
  set +a
fi

DEFAULT_TEAM_ID=$(grep -E 'DEVELOPMENT_TEAM:' "$IOS_DIR/project.yml" | head -n1 | awk '{print $2}' | tr -d '"'\''' || true)
APPLE_TEAM_ID="${APPLE_TEAM_ID:-$DEFAULT_TEAM_ID}"

ASC_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-${ASC_KEY_ID:-}}"
ASC_ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:-${ASC_ISSUER_ID:-}}"
ASC_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-${ASC_KEY_PATH:-}}"
ASC_KEY_BASE64="${APP_STORE_CONNECT_API_KEY_BASE64:-}"

DEFAULT_VERSION=$(grep -E 'MARKETING_VERSION:' "$IOS_DIR/project.yml" | head -n1 | awk '{print $2}' | tr -d '"'\''' || echo "1.0.0")
DEFAULT_BUILD=$(grep -E 'CURRENT_PROJECT_VERSION:' "$IOS_DIR/project.yml" | head -n1 | awk '{print $2}' | tr -d '"'\''' || echo "1")

MARKETING_VERSION="${ARG_VERSION:-$DEFAULT_VERSION}"
BUILD_NUMBER="${ARG_BUILD:-$DEFAULT_BUILD}"

if [[ -z "$APPLE_TEAM_ID" ]]; then
  log_error "APPLE_TEAM_ID is required. Set it in ios/.env or export APPLE_TEAM_ID=<10-char Team ID>."
  exit 1
fi

# ------------------------------------------------------------------------------
# 2. Resolve & Install App Store Connect API Key (.p8)
# ------------------------------------------------------------------------------
ASC_PRIVATE_KEYS_DIR="$HOME/.appstoreconnect/private_keys"
RESOLVED_KEY_FILE=""
CLEANUP_TEMP_KEY=false

if [[ -n "$ASC_KEY_ID" ]]; then
  TARGET_ALTOOL_KEY="$ASC_PRIVATE_KEYS_DIR/AuthKey_${ASC_KEY_ID}.p8"

  if [[ -n "$ASC_KEY_PATH" ]]; then
    # Expand ~ if present
    EXPANDED_PATH="${ASC_KEY_PATH/#\~/$HOME}"
    if [[ ! -f "$EXPANDED_PATH" && -f "$IOS_DIR/$ASC_KEY_PATH" ]]; then
      EXPANDED_PATH="$IOS_DIR/$ASC_KEY_PATH"
    elif [[ ! -f "$EXPANDED_PATH" && -f "$ROOT_DIR/$ASC_KEY_PATH" ]]; then
      EXPANDED_PATH="$ROOT_DIR/$ASC_KEY_PATH"
    fi

    if [[ ! -f "$EXPANDED_PATH" ]]; then
      log_error "App Store Connect API key file not found at: $ASC_KEY_PATH"
      exit 1
    fi

    mkdir -p "$ASC_PRIVATE_KEYS_DIR"
    if [[ "$(cd "$(dirname "$EXPANDED_PATH")" && pwd)/$(basename "$EXPANDED_PATH")" != "$TARGET_ALTOOL_KEY" ]]; then
      cp "$EXPANDED_PATH" "$TARGET_ALTOOL_KEY"
      chmod 600 "$TARGET_ALTOOL_KEY"
    fi
    RESOLVED_KEY_FILE="$TARGET_ALTOOL_KEY"
  elif [[ -n "$ASC_KEY_BASE64" ]]; then
    mkdir -p "$ASC_PRIVATE_KEYS_DIR"
    echo -n "$ASC_KEY_BASE64" | base64 --decode > "$TARGET_ALTOOL_KEY"
    chmod 600 "$TARGET_ALTOOL_KEY"
    RESOLVED_KEY_FILE="$TARGET_ALTOOL_KEY"
    CLEANUP_TEMP_KEY=true
  elif [[ -f "$TARGET_ALTOOL_KEY" ]]; then
    RESOLVED_KEY_FILE="$TARGET_ALTOOL_KEY"
  elif [[ -f "$IOS_DIR/AuthKey_${ASC_KEY_ID}.p8" ]]; then
    mkdir -p "$ASC_PRIVATE_KEYS_DIR"
    cp "$IOS_DIR/AuthKey_${ASC_KEY_ID}.p8" "$TARGET_ALTOOL_KEY"
    chmod 600 "$TARGET_ALTOOL_KEY"
    RESOLVED_KEY_FILE="$TARGET_ALTOOL_KEY"
  elif [[ -f "$ROOT_DIR/AuthKey_${ASC_KEY_ID}.p8" ]]; then
    mkdir -p "$ASC_PRIVATE_KEYS_DIR"
    cp "$ROOT_DIR/AuthKey_${ASC_KEY_ID}.p8" "$TARGET_ALTOOL_KEY"
    chmod 600 "$TARGET_ALTOOL_KEY"
    RESOLVED_KEY_FILE="$TARGET_ALTOOL_KEY"
  fi
fi

# Validate required credentials
MISSING_VARS=()
if [[ -z "$ASC_KEY_ID" ]]; then
  MISSING_VARS+=("APP_STORE_CONNECT_API_KEY_ID (or ASC_KEY_ID)")
fi
if [[ -z "$ASC_ISSUER_ID" ]]; then
  MISSING_VARS+=("APP_STORE_CONNECT_ISSUER_ID (or ASC_ISSUER_ID)")
fi
if [[ -z "$RESOLVED_KEY_FILE" ]]; then
  MISSING_VARS+=("APP_STORE_CONNECT_API_KEY_PATH (or APP_STORE_CONNECT_API_KEY_BASE64)")
fi

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
  if [[ "$ARCHIVE_ONLY" == true ]]; then
    log_warn "App Store Connect API Key credentials are not fully set (${MISSING_VARS[*]})."
    log_warn "Proceeding in --archive-only mode using local Xcode account session (-allowProvisioningUpdates)."
  else
    log_error "Missing required App Store Connect API credentials:"
    for var in "${MISSING_VARS[@]}"; do
      echo -e "  - ${RED}$var${NC}" >&2
    done
    echo "" >&2
    echo "Create ios/.env (or export in shell) with:" >&2
    echo "  APPLE_TEAM_ID=$APPLE_TEAM_ID" >&2
    echo "  APP_STORE_CONNECT_API_KEY_ID=YOUR_KEY_ID" >&2
    echo "  APP_STORE_CONNECT_ISSUER_ID=YOUR_ISSUER_UUID" >&2
    echo "  APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_YOUR_KEY_ID.p8" >&2
    exit 1
  fi
fi

# ------------------------------------------------------------------------------
# 3. Inspect Local Keychain Signing Identities
# ------------------------------------------------------------------------------
log_info "Checking local macOS Keychain for codesigning identities..."
IDENTITIES_OUTPUT=$(security find-identity -v -p codesigning 2>&1 || true)
echo "$IDENTITIES_OUTPUT"

if ! echo "$IDENTITIES_OUTPUT" | grep -qE "Apple Distribution|iOS Distribution"; then
  log_warn "No 'Apple Distribution' certificate was detected in your local Keychain!"
  log_warn "App Store / TestFlight export requires an Apple Distribution certificate."
  log_warn "To add one in 10 seconds:"
  log_warn "  1. Open Xcode -> Settings (Cmd+,) -> Accounts"
  log_warn "  2. Select your Apple ID / Team ($APPLE_TEAM_ID) -> Manage Certificates..."
  log_warn "  3. Click '+' -> choose 'Apple Distribution' (or import your .p12 certificate)."
fi

# ------------------------------------------------------------------------------
# 4. Generate Xcode Project & Dynamic ExportOptions.plist
# ------------------------------------------------------------------------------
cd "$IOS_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  log_error "'xcodegen' is not installed. Install it via: brew install xcodegen"
  exit 1
fi

log_info "Regenerating NamazVakti.xcodeproj via XcodeGen..."
xcodegen generate

BUILD_DIR="$IOS_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/NamazVakti.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTIONS_PLIST="$BUILD_DIR/ExportOptions.plist"

rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
mkdir -p "$BUILD_DIR"

log_info "Generating automatic-signing ExportOptions.plist (Team: $APPLE_TEAM_ID)..."
cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>destination</key>
	<string>export</string>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
	<key>method</key>
	<string>app-store-connect</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>teamID</key>
	<string>${APPLE_TEAM_ID}</string>
	<key>testFlightInternalTestingOnly</key>
	<false/>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
EOF

# Build authentication arguments for automatic provisioning via ASC API Key
AUTH_ARGS=(-allowProvisioningUpdates)
if [[ -n "$RESOLVED_KEY_FILE" && -n "$ASC_KEY_ID" && -n "$ASC_ISSUER_ID" ]]; then
  AUTH_ARGS+=(
    -authenticationKeyPath "$RESOLVED_KEY_FILE"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
fi

# ------------------------------------------------------------------------------
# 5. Archive iOS App (.xcarchive)
# ------------------------------------------------------------------------------
log_info "Archiving NamazVakti v${MARKETING_VERSION} (Build ${BUILD_NUMBER}) for generic iOS device..."
xcodebuild archive \
  -project NamazVakti.xcodeproj \
  -scheme NamazVakti \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  "${AUTH_ARGS[@]}" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  MARKETING_VERSION="$MARKETING_VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

log_ok "Archive created at: $ARCHIVE_PATH"

# ------------------------------------------------------------------------------
# 6. Export Signed .ipa
# ------------------------------------------------------------------------------
log_info "Exporting signed .ipa for App Store Connect / TestFlight..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -exportPath "$EXPORT_DIR" \
  "${AUTH_ARGS[@]}"

IPA_FILE=$(find "$EXPORT_DIR" -name "*.ipa" | head -n 1 || true)
if [[ -z "$IPA_FILE" ]]; then
  log_error "Export completed, but no .ipa file was found in $EXPORT_DIR"
  exit 1
fi

log_ok "Signed IPA exported to: $IPA_FILE"

# ------------------------------------------------------------------------------
# 7. Upload to TestFlight (unless --archive-only)
# ------------------------------------------------------------------------------
if [[ "$ARCHIVE_ONLY" == true ]]; then
  log_ok "Skipped TestFlight upload (--archive-only)."
  echo ""
  echo "To upload manually later:"
  echo "  xcrun altool --upload-app --type ios --file \"$IPA_FILE\" --apiKey \"\$APP_STORE_CONNECT_API_KEY_ID\" --apiIssuer \"\$APP_STORE_CONNECT_ISSUER_ID\" --verbose"
  exit 0
fi

log_info "Uploading $(basename "$IPA_FILE") (v${MARKETING_VERSION} build ${BUILD_NUMBER}) to TestFlight..."
xcrun altool --upload-app \
  --type ios \
  --file "$IPA_FILE" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID" \
  --verbose

if [[ "$CLEANUP_TEMP_KEY" == true && -f "$RESOLVED_KEY_FILE" ]]; then
  rm -f "$RESOLVED_KEY_FILE"
fi

log_ok "Successfully uploaded NamazVakti v${MARKETING_VERSION} (${BUILD_NUMBER}) to App Store Connect / TestFlight!"
