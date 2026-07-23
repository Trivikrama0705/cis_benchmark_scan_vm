#!/bin/bash
set -e

OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release 2>/dev/null | tr -d '"' || echo "unknown")
echo "Detected OS: $OS_ID"

sudo apt-get update -y 2>/dev/null || true
sudo apt-get install -y openscap-scanner scap-security-guide 2>/dev/null || \
sudo yum install -y openscap-scanner scap-security-guide 2>/dev/null || true

CONTENT=$(find /usr/share/xml/scap/ssg/content/ -iname "*${OS_ID}*" 2>/dev/null | head -1)
if [ -z "$CONTENT" ]; then
  CONTENT=$(find /usr/share/xml/scap/ssg/content/ -iname "*ubuntu*" 2>/dev/null | head -1)
fi

oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_level1_server \
  --results /tmp/results.xml \
  --report /tmp/report.html \
  "$CONTENT" || true

base64 -w 0 /tmp/report.html
