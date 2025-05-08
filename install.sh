#!/bin/bash

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

echo "Starting Hugo installation process on Ubuntu..."

# Install necessary tools (curl, wget) if they are missing
echo "Ensuring necessary tools (curl, wget) are installed..."
apt update
apt install -y curl wget

# Check if curl or wget is now available
if ! command_exists curl && ! command_exists wget; then
  echo "Failed to install curl or wget. Cannot proceed with binary download. Exiting."
  exit 1
fi
echo "curl or wget successfully installed or already present."


# Try installing using apt-get first
echo "Trying to install Hugo via apt-get..."
apt-get update
apt-get install -y hugo

# Check if hugo is now available and get its version from apt
APT_HUGO_VERSION=""
if command_exists hugo; then
  APT_HUGO_VERSION=$(hugo version 2>&1 | head -n 1 | awk '{print $5}' | sed 's/^v//')
  echo "Hugo version installed via apt-get: v${APT_HUGO_VERSION}"
else
  echo "Hugo command not found after apt-get installation attempt."
fi

# Get the latest Hugo version from GitHub releases
echo "Checking the latest Hugo version from GitHub..."
LATEST_HUGO_VERSION=$(curl -s https://api.github.com/repos/gohugoio/hugo/releases/latest | grep '"tag_name":' | sed -E 's/.*"v(.*)".*/\1/')

if [ -z "$LATEST_HUGO_VERSION" ]; then
  echo "Could not determine the latest Hugo version from GitHub. Exiting."
  exit 1
fi

echo "Latest Hugo version from GitHub is v${LATEST_HUGO_VERSION}"

# Compare versions and decide whether to install the binary
if [ -n "$APT_HUGO_VERSION" ] && dpkg --compare-versions "$APT_HUGO_VERSION" ge "$LATEST_HUGO_VERSION"; then
  echo "The version installed via apt-get (v${APT_HUGO_VERSION}) is the latest or newer. Using the apt-get version."
  exit 0
else
  if [ -n "$APT_HUGO_VERSION" ]; then
    echo "The version installed via apt-get (v${APT_HUGO_VERSION}) is older than the latest (v${LATEST_HUGO_VERSION}). Installing the latest binary."
    # Optionally remove the apt version if you only want the latest binary
    # echo "Removing the apt-get version of Hugo... (Optional)"
    # apt-get remove -y hugo
  else
    echo "Hugo was not successfully installed via apt-get. Installing the latest binary."
  fi
fi

# Binary installation
echo "Attempting to install the latest Hugo binary from GitHub releases..."

# Determine the correct binary name based on architecture
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
HUGO_BINARY=""

case "$ARCH" in
  amd64|x86_64)
    HUGO_BINARY="hugo_extended_${LATEST_HUGO_VERSION}_linux-amd64.tar.gz"
    ;;
  arm64|aarch64)
    HUGO_BINARY="hugo_extended_${LATEST_HUGO_VERSION}_linux-arm64.tar.gz"
    ;;
  armhf|armv7l)
    HUGO_BINARY="hugo_extended_${LATEST_VERSION}_linux-armhf.tar.gz" # Note: Used LATEST_VERSION here, should be LATEST_HUGO_VERSION
    ;;
  *)
    echo "Unsupported architecture: ${ARCH}. Cannot download binary."
    exit 1
    ;;
esac

# Fix: Corrected the variable name in the armhf case
if [ "$ARCH" = "armhf" ] || [ "$ARCH" = "armv7l" ]; then
  HUGO_BINARY="hugo_extended_${LATEST_HUGO_VERSION}_linux-armhf.tar.gz"
fi


HUGO_DOWNLOAD_URL="https://github.com/gohugoio/hugo/releases/download/v${LATEST_HUGO_VERSION}/${HUGO_BINARY}"
HUGO_TEMP_FILE="/tmp/${HUGO_BINARY}"

echo "Downloading ${HUGO_DOWNLOAD_URL}..."

# Download the binary using either curl or wget
if command_exists curl; then
  curl -L "${HUGO_DOWNLOAD_URL}" -o "${HUGO_TEMP_FILE}"
elif command_exists wget; then
  wget "${HUGO_DOWNLOAD_URL}" -O "${HUGO_TEMP_FILE}"
else
  # This case should theoretically not be reached due to the initial check, but as a fallback
  echo "Neither curl nor wget found despite installation attempt. Cannot download Hugo binary. Exiting."
  exit 1
fi


if [ ! -f "${HUGO_TEMP_FILE}" ]; then
  echo "Download failed. Hugo binary not found at ${HUGO_TEMP_FILE}. Exiting."
  exit 1
fi

echo "Extracting to /usr/local/bin/..."

# Extract the binary to a directory in the PATH
# Ensure /usr/local/bin exists
mkdir -p /usr/local/bin/
tar -xzf "${HUGO_TEMP_FILE}" -C /usr/local/bin/

# Clean up the temporary file
rm "${HUGO_TEMP_FILE}"

# Verify installation
if command_exists hugo; then
  echo "Hugo installed successfully (binary)."
  hugo version
else
  echo "Hugo installation failed. The 'hugo' command was not found in the PATH after installation."
  exit 1
fi

echo "Hugo installation process finished."
exit 0
