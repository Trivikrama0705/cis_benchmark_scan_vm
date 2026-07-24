#!/bin/bash
set -e

echo "=== SCAN SCRIPT STARTED ==="
SAS_URL="__SAS_URL_PLACEHOLDER__"

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

if [ -z "$LATEST_URL" ]; then
  echo "ERROR: Could not resolve SCAP content download URL"
  exit 1
fi

curl -sL -o /tmp/content.zip "$LATEST_URL"
mkdir -p /tmp/scap-content
unzip -oq /tmp/content.zip -d /tmp/scap-content

CONTENT=$(find /tmp/scap-content \( -iname "*-ds.xml" -o -iname "*-xccdf.xml" \) | grep -i ubuntu | head -1)
if [ -z "$CONTENT" ]; then
  CONTENT=$(find /tmp/scap-content \( -iname "*-ds.xml" -o -iname "*-xccdf.xml" \) | grep -i debian | head -1)
fi
if [ -z "$CONTENT" ]; then
  CONTENT=$(find /tmp/scap-content \( -iname "*-ds.xml" -o -iname "*-xccdf.xml" \) | head -1)
fi
echo "Using content file: $CONTENT"

if [ -z "$CONTENT" ]; then
  echo "ERROR: No usable SCAP content found."
  exit 1
fi

echo "=== Running scan ==="
oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_level1_server \
  --results /tmp/results.xml \
  --report /tmp/report.html \
  "$CONTENT" > /dev/null 2>&1 || true

ls -la /tmp/report.html || { echo "ERROR: report.html was not created"; exit 1; }

echo "=== Uploading report directly to blob storage (bypasses stdout size limit) ==="
if [ "$SAS_URL" == "__SAS_URL_PLACEHOLDER__" ] || [ -z "$SAS_URL" ]; then
  echo "ERROR: SAS_URL placeholder was not replaced before sending script"
  exit 1
fi

curl -sf -X PUT -T /tmp/report.html \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: text/html" \
  "$SAS_URL"

echo "UPLOAD_COMPLETE"
echo "=== SCAN SCRIPT FINISHED ==="
