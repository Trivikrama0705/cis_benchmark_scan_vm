#!/bin/bash
set -e

echo "=== SCAN SCRIPT STARTED ==="
SAS_URL_B64="__SAS_URL_PLACEHOLDER__"
SAS_URL=$(echo "$SAS_URL_B64" | base64 -d)

OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release 2>/dev/null | tr -d '"' || echo "unknown")
echo "Detected OS: $OS_ID"

echo "=== Cleaning up leftovers from any previous run ==="
rm -rf /tmp/scap-content /tmp/content.zip /tmp/report.html /tmp/results.xml

echo "=== Installing OpenSCAP scanner + tools ==="
sudo apt-get update -y
sudo add-apt-repository universe -y || true
sudo apt-get update -y
sudo apt-get install -y openscap-scanner unzip curl

which oscap || { echo "ERROR: oscap not installed"; exit 1; }

echo "=== Downloading latest SCAP content from ComplianceAsCode ==="
LATEST_URL=$(curl -s https://api.github.com/repos/ComplianceAsCode/content/releases/latest \
  | grep "browser_download_url.*\.zip" | head -1 | cut -d '"' -f 4)
echo "Content package URL: $LATEST_URL"

curl -sL -o /tmp/content.zip "$LATEST_URL"
mkdir -p /tmp/scap-content
unzip -oq /tmp/content.zip -d /tmp/scap-content

CONTENT=$(find /tmp/scap-content \( -iname "*-ds.xml" -o -iname "*-xccdf.xml" \) | grep -i ubuntu | head -1)
[ -z "$CONTENT" ] && CONTENT=$(find /tmp/scap-content \( -iname "*-ds.xml" -o -iname "*-xccdf.xml" \) | head -1)
echo "Using content file: $CONTENT"

echo "=== Running scan (showing rule-by-rule progress) ==="
oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_level1_server \
  --results /tmp/results.xml \
  --report /tmp/report.html \
  "$CONTENT" | grep -E "^(Title|Rule|Result)" || true

ls -la /tmp/report.html || { echo "ERROR: report.html was not created"; exit 1; }

echo "=== Compliance summary ==="
PASS_COUNT=$(grep -c "<result>pass</result>" /tmp/results.xml || echo 0)
FAIL_COUNT=$(grep -c "<result>fail</result>" /tmp/results.xml || echo 0)
echo "Passed: $PASS_COUNT | Failed: $FAIL_COUNT"

echo "=== Uploading report directly to blob storage ==="
if [ "$SAS_URL" == "__SAS_URL_PLACEHOLDER__" ] || [ -z "$SAS_URL" ]; then
  echo "ERROR: SAS_URL was not decoded correctly"
  exit 1
fi

curl -sf -X PUT -T /tmp/report.html \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: text/html" \
  "$SAS_URL"

echo "UPLOAD_COMPLETE"
echo "=== SCAN SCRIPT FINISHED ==="
