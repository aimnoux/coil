#!/bin/bash
# Publishes site/ (privacy policy, support, landing page) to a separate PUBLIC GitHub repository
# with GitHub Pages, because the app repository is private.
#
# Usage: scripts/publish-site.sh you@example.com [repo-name]
# Result: https://<github-user>.github.io/<repo-name>/privacy.html
set -euo pipefail

EMAIL="${1:?Pass the contact email shown on the pages}"
REPO="${2:-coil-app}"
USER="$(gh api user --jq .login)"
WORK="$(mktemp -d)"

cp -R "$(dirname "$0")/../site/." "$WORK/"
# Fill in the contact address.
find "$WORK" -name '*.html' -exec sed -i '' "s/CONTACT_EMAIL/${EMAIL}/g" {} +

cd "$WORK"
git init -q -b main
git add -A
git commit -q -m "Publish Coil website"

if ! gh repo view "$USER/$REPO" >/dev/null 2>&1; then
  gh repo create "$REPO" --public --description "Coil habit tracker: privacy policy and support" --source=. --push
else
  git remote add origin "https://github.com/$USER/$REPO.git"
  git push -q -f origin main
fi

# Serve the main branch root with GitHub Pages (ignore the error if it is already on).
gh api -X POST "repos/$USER/$REPO/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 || true

echo "Published. In a minute or two the pages will be at:"
echo "  https://$USER.github.io/$REPO/privacy.html"
echo "  https://$USER.github.io/$REPO/support.html"
