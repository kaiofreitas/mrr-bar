#!/bin/bash
# Usage: ./publish.sh <version> <release-notes>
# Example: ./publish.sh 1.1 "Fixed MRR calculation for annual plans"
set -e

VERSION="${1:?Usage: ./publish.sh <version> <release-notes>}"
NOTES="${2:-"Bug fixes and improvements"}"
APP_NAME="MRR Bar"
ZIP_NAME="MRRBar-$VERSION.zip"
SIGN_UPDATE=".build/artifacts/sparkle/Sparkle/bin/sign_update"

# 1. Update version in build script
sed -i '' "s/^VERSION=.*/VERSION=\"$VERSION\"/" build-app.sh

# 2. Build the .app
./build-app.sh

# 3. Zip it
ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_NAME"
echo "Created $ZIP_NAME"

# 4. Sign and get appcast item
echo ""
echo "Signed update info:"
"$SIGN_UPDATE" "$ZIP_NAME"

echo ""
echo "------------------------------------------------------------"
echo "Next steps:"
echo "  1. Upload $ZIP_NAME to GitHub Releases as v$VERSION"
echo "  2. Copy the <item> block above into appcast.xml"
echo "  3. Push appcast.xml to your GitHub Pages branch"
echo "------------------------------------------------------------"
