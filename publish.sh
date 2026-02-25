#!/bin/bash
# Usage: ./publish.sh <version> <release-notes>
# Example: ./publish.sh 1.1 "Fixed MRR calculation for annual plans"
set -e

VERSION="${1:?Usage: ./publish.sh <version> <release-notes>}"
NOTES="${2:-"Bug fixes and improvements"}"
APP_NAME="MRR Bar"
DMG_NAME="MRRBar-$VERSION.dmg"
ZIP_NAME="MRRBar-$VERSION.zip"
SIGN_UPDATE=".build/artifacts/sparkle/Sparkle/bin/sign_update"

# 1. Bump version
sed -i '' "s/^VERSION=.*/VERSION=\"$VERSION\"/" build-app.sh

# 2. Build the .app
./build-app.sh

# 3. Create DMG (for distribution / download)
echo "Creating DMG..."
rm -f "$DMG_NAME"
create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 540 380 \
  --icon-size 128 \
  --icon "$APP_NAME.app" 130 175 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 410 175 \
  "$DMG_NAME" \
  "$APP_NAME.app"
echo "Created $DMG_NAME"

# 4. Create zip (for Sparkle auto-updates)
echo "Creating zip for Sparkle..."
ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_NAME"

# 5. Sign the zip
echo ""
echo "Sparkle signature:"
"$SIGN_UPDATE" "$ZIP_NAME"

echo ""
echo "------------------------------------------------------------"
echo "Next steps:"
echo "  1. Upload $DMG_NAME and $ZIP_NAME to GitHub Releases as v$VERSION"
echo "  2. Copy the edSignature + length above into appcast.xml"
echo "  3. Add a new <item> block to appcast.xml and push"
echo "  gh release create v$VERSION $DMG_NAME $ZIP_NAME --title \"$APP_NAME $VERSION\" --notes \"$NOTES\""
echo "------------------------------------------------------------"
