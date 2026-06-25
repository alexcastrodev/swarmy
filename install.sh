#!/bin/sh
set -e

REPO="alexcastrodev/swarmy"
INSTALL_DIR="/usr/local/bin"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

case "$OS" in
  linux)  TARGET="linux-${ARCH}" ;;
  darwin) TARGET="darwin-${ARCH}" ;;
  *)      echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac

VERSION=$(curl -sI "https://github.com/${REPO}/releases/latest" | grep -i location | sed 's/.*tag\///' | tr -d '\r\n')

if [ -z "$VERSION" ]; then
  echo "Could not determine latest version" >&2
  exit 1
fi

URL="https://github.com/${REPO}/releases/download/${VERSION}/swarmy-${TARGET}.tar.gz"

echo "Installing swarmy ${VERSION} (${TARGET})..."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

curl -sL "$URL" | tar xz -C "$TMP"

if [ -w "$INSTALL_DIR" ]; then
  mv "$TMP/swarmy" "$INSTALL_DIR/swarmy"
else
  sudo mv "$TMP/swarmy" "$INSTALL_DIR/swarmy"
fi

echo "swarmy installed to ${INSTALL_DIR}/swarmy"
