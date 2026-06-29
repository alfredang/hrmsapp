#!/usr/bin/env bash
# Fast App Store submission from your Mac: archive -> export -> UPLOAD VIA THE
# APP STORE CONNECT API KEY (xcrun altool --apiKey), no CI round-trip.
#
# This is the quick path to get a build into App Store Connect / TestFlight: it reuses the
# org-standard ASC API key (the same .p8 used by ci_submit.py) as the upload token, so there is
# no notarytool/Transporter password to manage. After it finishes, the build appears under the
# app's TestFlight/Builds tab within a few minutes of processing; attach it to a version and
# submit (manually, or with `ci_submit.py submit`).
#
# Prereqit: the app record must already EXIST in App Store Connect (the API cannot create apps).
# The App ID + an "App Store" provisioning profile + an "Apple Distribution" cert must exist; this
# script signs manually with them.
#
# Env / overrides (org-credentials.env + project .env are auto-sourced):
#   ASC_KEY_ID, ASC_ISSUER_ID            ASC API key (from org-credentials.env)
#   ASC_PRIVATE_KEY_PATH                 path to AuthKey_<id>.p8 (default ~/.appstoreconnect/...)
#   ASC_BUNDLE_ID                        e.g. com.tertiaryinfotech.plannerapp  (REQUIRED)
#   SCHEME        Xcode scheme           (default: first .xcodeproj basename)
#   PROJECT       path to .xcodeproj     (default: autodetected)
#   PROFILE       App Store profile name (default: "<Scheme> App Store")
#   SIGN_IDENTITY signing identity       (default: "Apple Distribution: <from cert>")
#   ENTITLEMENTS  CODE_SIGN_ENTITLEMENTS override (optional; e.g. a no-iCloud Local.entitlements)
#   BUILD_NUMBER  CFBundleVersion        (default: UTC timestamp yymmddHHMM — unique & increasing)
#   SKIP_ARCHIVE  =1 to reuse /tmp/<Scheme>.xcarchive (re-export+upload only)
set -uo pipefail

ORG_ENV="$HOME/.claude/skills/ios-auto-release/org-credentials.env"
[ -f "$ORG_ENV" ] && { set -a; . "$ORG_ENV"; set +a; }
[ -f .env ] && { set -a; . ./.env; set +a; }
if [ -f project.yml ] && command -v xcodegen >/dev/null 2>&1; then xcodegen generate >/dev/null; fi

PROJECT="${PROJECT:-$(ls -d *.xcodeproj 2>/dev/null | head -1)}"
SCHEME="${SCHEME:-$(basename "${PROJECT%.xcodeproj}")}"
[ -n "$PROJECT" ] || { echo "[upload] no .xcodeproj found"; exit 1; }
: "${ASC_BUNDLE_ID:?set ASC_BUNDLE_ID (the app's bundle id) in .env}"
: "${ASC_KEY_ID:?missing ASC_KEY_ID}" ; : "${ASC_ISSUER_ID:?missing ASC_ISSUER_ID}"
KEY="${ASC_PRIVATE_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"
KEY="${KEY/#\~/$HOME}"
[ -f "$KEY" ] || { echo "[upload] private key not found at $KEY"; exit 1; }

TEAM_ID="${TEAM_ID:-$(security find-identity -v -p codesigning | sed -n 's/.*Apple Distribution: .*(\([A-Z0-9]\{10\}\)).*/\1/p' | head -1)}"
SIGN_IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | grep -o 'Apple Distribution: [^"]*' | head -1)}"
PROFILE="${PROFILE:-$SCHEME App Store}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%y%m%d%H%M)}"
ARCHIVE="/tmp/${SCHEME}.xcarchive"
EXPORT_DIR="/tmp/${SCHEME}-export"

echo "[upload] scheme=$SCHEME bundle=$ASC_BUNDLE_ID team=$TEAM_ID build=$BUILD_NUMBER"
echo "[upload] identity='$SIGN_IDENTITY' profile='$PROFILE'"

ENT_ARG=(); [ -n "${ENTITLEMENTS:-}" ] && ENT_ARG=(CODE_SIGN_ENTITLEMENTS="$ENTITLEMENTS")

if [ "${SKIP_ARCHIVE:-0}" != "1" ]; then
  rm -rf "$ARCHIVE" "$EXPORT_DIR"
  echo "[upload] archiving..."
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    PROVISIONING_PROFILE_SPECIFIER="$PROFILE" DEVELOPMENT_TEAM="$TEAM_ID" \
    "${ENT_ARG[@]}" archive || { echo "[upload] archive failed"; exit 1; }
fi

cat > /tmp/${SCHEME}-ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>${SIGN_IDENTITY}</string>
  <key>provisioningProfiles</key><dict>
    <key>${ASC_BUNDLE_ID}</key><string>${PROFILE}</string>
  </dict>
  <key>destination</key><string>export</string>
</dict></plist>
EOF

echo "[upload] exporting IPA..."
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist /tmp/${SCHEME}-ExportOptions.plist || { echo "[upload] export failed"; exit 1; }
IPA="$(ls "$EXPORT_DIR"/*.ipa 2>/dev/null | head -1)"
[ -f "$IPA" ] || { echo "[upload] no IPA produced"; exit 1; }

# Sanity-check the two most common altool rejections BEFORE the slow upload.
unzip -l "$IPA" | grep -qi "AppIcon" || echo "[upload] WARN: no AppIcon in bundle (altool 90022/90713 will reject)"

echo "[upload] uploading via ASC API key (altool)..."
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" || { echo "[upload] upload failed (see errors above)"; exit 1; }

echo "[upload] DONE. Build $BUILD_NUMBER uploaded; it appears under the app's Builds/TestFlight tab"
echo "        after a few minutes of processing. Attach it to a version and submit"
echo "        (UI, or: python3 \$ORG/scripts/ci_submit.py submit --version <v> --build $BUILD_NUMBER)."
