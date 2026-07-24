#!/bin/bash
set -e

echo "=== SCAN SCRIPT STARTED ==="
SAS_URL="$1"   # passed in as a script parameter

OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release 2>/dev/null | tr -d '"' || echo "unknown")
echo "Detected OS: $OS_ID"

rm -rf /tmp/scap-content /tmp/content.zip /tmp/report.html /tmp/results.xml

sudo apt-get update -y
sudo add-apt-repository universe -y || true
sudo apt-get update -y
sudo apt-get install -y openscap-scanner unzip curl

LATEST_URL=$(curl -s https://api.github.com/repos/ComplianceAsCode/content/releases/latest \
  | grep "browser_download_url.*\.zip" | head -1 | cut -d '"' -f 4)
curl -sL -o /tmp/content.zip "$LATEST_URL"
mkdir -p /tmp/scap-content
unzip -oq /tmp/content.zip -d /tmp/scap-content

CONTENT=$(find /tmp/scap-content \( -iname "*-ds.xml" -o -iname "*-xccdf.xml" \) | grep -i ubuntu | head -1)
[ -z "$CONTENT" ] && CONTENT=$(find /tmp/scap-content \( -iname "*-ds.xml" -o -iname "*-xccdf.xml" \) | head -1)
echo "Using content file: $CONTENT"

oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_level1_server \
  --results /tmp/results.xml \
  --report /tmp/report.html \
  "$CONTENT" || true

ls -la /tmp/report.html

echo "=== Uploading report directly to blob storage (bypasses stdout size limit) ==="
curl -sf -X PUT -T /tmp/report.html \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: text/html" \
  "$SAS_URL"

echo "UPLOAD_COMPLETE"
