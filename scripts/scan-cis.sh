#!/bin/bash
set -e

echo "=== SCAN SCRIPT STARTED ==="

OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release 2>/dev/null | tr -d '"' || echo "unknown")
OS_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release 2>/dev/null | tr -d '"' || echo "")
echo "Detected OS: $OS_ID $OS_VERSION"

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
unzip -q /tmp/content.zip -d /tmp/scap-content

echo "=== Locating best-matching content file for $OS_ID $OS_VERSION ==="
CONTENT=$(find /tmp/scap-content -iname "ssg-${OS_ID}${OS_VERSION//./}-xccdf.xml" 2>/dev/null | head -1)
if [ -z "$CONTENT" ]; then
  CONTENT=$(find /tmp/scap-content -iname "*${OS_ID}*-xccdf.xml" 2>/dev/null | head -1)
fi
if [ -z "$CONTENT" ]; then
  echo "No exact match for $OS_ID, falling back to Ubuntu content"
  CONTENT=$(find /tmp/scap-content -iname "ssg-ubuntu2204-xccdf.xml" 2>/dev/null | head -1)
fi
echo "Using content file: $CONTENT"

if [ -z "$CONTENT" ]; then
  echo "ERROR: No usable SCAP content found. Available files:"
  find /tmp/scap-content -iname "*xccdf.xml" | head -20
  exit 1
fi

echo "=== Running scan ==="
oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_level1_server \
  --results /tmp/results.xml \
  --report /tmp/report.html \
  "$CONTENT" || true

ls -la /tmp/report.html || { echo "ERROR: report.html was not created"; exit 1; }

echo "=== SCAN SCRIPT FINISHED ==="
base64 -w 0 /tmp/report.html
