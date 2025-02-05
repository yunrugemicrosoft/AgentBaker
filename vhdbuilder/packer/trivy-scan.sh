#!/usr/bin/env bash
set -euxo pipefail

TRIVY_REPORT_JSON_PATH=/opt/azure/containers/trivy-report.json
TRIVY_REPORT_TABLE_PATH=/opt/azure/containers/trivy-table.txt
TRIVY_VERSION="0.40.0"
TRIVY_ARCH=""

arch="$(uname -m)"
if [ "${arch,,}" == "arm64" ] || [ "${arch,,}" == "aarch64" ]; then
    TRIVY_ARCH="Linux-ARM64"
elif [ "${arch,,}" == "x86_64" ]; then
    TRIVY_ARCH="Linux-64bit"
else
    echo "invalid architecture ${arch,,}"
    exit 1
fi

mkdir -p "$(dirname "${TRIVY_REPORT_JSON_PATH}")"
mkdir -p "$(dirname "${TRIVY_REPORT_TABLE_PATH}")"

wget "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_${TRIVY_ARCH}.tar.gz"
tar -xvzf "trivy_${TRIVY_VERSION}_${TRIVY_ARCH}.tar.gz"
rm "trivy_${TRIVY_VERSION}_${TRIVY_ARCH}.tar.gz"
chmod a+x trivy 

./trivy --scanners vuln rootfs -f json --ignore-unfixed --severity HIGH,CRITICAL -o "${TRIVY_REPORT_JSON_PATH}" /
./trivy --scanners vuln rootfs -f table --ignore-unfixed --severity HIGH,CRITICAL -o "${TRIVY_REPORT_TABLE_PATH}" /


rm ./trivy 

chmod a+r "${TRIVY_REPORT_JSON_PATH}"
chmod a+r "${TRIVY_REPORT_TABLE_PATH}"
