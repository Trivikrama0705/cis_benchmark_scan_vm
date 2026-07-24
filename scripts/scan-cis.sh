#!/bin/bash
set -e

echo "=== SCAN SCRIPT STARTED ==="

OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release 2>/dev/null | tr -d '"' || echo "unknown")
echo "Detected OS: $OS_ID"

echo "=== Installing OpenSCAP ==="
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo add-apt-repository universe -y || true
  sudo apt-get update -y
  sudo apt-get install -y openscap-scanner scap-security-guide
elif command -v yum >/dev/null 2>&1; then
  sudo yum install -y openscap-scanner scap-security-guide
fi

echo "=== Checking for OpenSCAP install ==="
which oscap || { echo "ERROR: oscap not installed after apt install"; exit 1; }

CONTENT=$(find /usr/share/xml/scap/ssg/content/ -iname "*${OS_ID}*" 2>/dev/null | head -1)
if [ -z "$CONTENT" ]; then
  CONTENT=$(find /usr/share/xml/scap/ssg/content/ -iname "*ubuntu*" 2>/dev/null | head -1)
fi
echo "Using content file: $CONTENT"

if [ -z "$CONTENT" ]; then
  echo "ERROR: No SCAP content file found. Listing available content:"
  find /usr/share/xml/scap/ssg/content/ 2>&1
  exit 1
fi

oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_level1_server \
  --results /tmp/results.xml \
  --report /tmp/report.html \
  "$CONTENT" || true

echo "=== Report file check ==="
ls -la /tmp/report.html || { echo "ERROR: report.html was not created"; exit 1; }

echo "=== SCAN SCRIPT FINISHED ==="
base64 -w 0 /tmp/report.html
