#!/bin/bash
set -e

echo "=== SCAN SCRIPT STARTED ==="

OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release 2>/dev/null | tr -d '"' || echo "unknown")
OS_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release 2>/dev/null | tr -d '"' || echo "")
echo "Detected OS: $OS_ID $OS_VERSION"

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

echo "=== FULL LIST of all XML content files in the package ==="
find /tmp/scap-content -iname "*.xml" | sort

echo "=== Searching for a usable Ubuntu/Debian datastream or xccdf file ==="
CONTENT=$(find /tmp/scap-content \( -iname "*-ds.xml" -o -iname "*-xccdf.xml" \) \
  | grep -i ubuntu | head -1)

if [ -z "$CONTENT" ]; then
  echo "No ubuntu-named file found, trying debian as closest relative..."
  CONTENT=$(find /tmp/scap-content \( -iname "*-ds.xml" -o -iname "*-xccdf.xml" \) \
    | grep -i debian | head -1)
fi

if [ -z "$CONTENT" ]; then
  echo "Still nothing - picking the FIRST available datastream/xccdf file as last resort"
  CONTENT=$(find /tmp/scap-content \( -iname "*-ds.xml" -o -iname "*-xccdf.xml" \) | head -1)
fi

echo "Using content file: $CONTENT"

if [ -z "$CONTENT" ]; then
  echo "ERROR: Truly no usable content file found anywhere in the package."
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
