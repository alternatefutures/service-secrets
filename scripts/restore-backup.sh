#!/bin/bash
# Restore secrets from an encrypted Arweave backup
#
# Usage:
#   ./restore-backup.sh <arweave-tx-id> <age-private-key-file>
#
# Example:
#   ./restore-backup.sh ar://abc123xyz ~/.age-key.txt
#
# Prerequisites:
#   - age (brew install age)
#   - jq (brew install jq)
#   - infisical CLI (brew install infisical/get-cli/infisical)

set -e

ARWEAVE_TX="$1"
AGE_KEY_FILE="$2"

if [ -z "$ARWEAVE_TX" ] || [ -z "$AGE_KEY_FILE" ]; then
  echo "Usage: $0 <arweave-tx-id> <age-private-key-file>"
  echo ""
  echo "Example:"
  echo "  $0 ar://abc123xyz ~/.age-key.txt"
  exit 1
fi

if [ ! -f "$AGE_KEY_FILE" ]; then
  echo "Error: Age key file not found: $AGE_KEY_FILE"
  exit 1
fi

# Extract transaction ID from ar:// URL if needed
TX_ID=$(echo "$ARWEAVE_TX" | sed 's|ar://||')

echo "Downloading backup from Arweave..."
BACKUP_FILE="backup-restore.tar.gz.age"
curl -sL "https://arweave.net/$TX_ID" -o "$BACKUP_FILE"

if [ ! -s "$BACKUP_FILE" ]; then
  echo "Error: Failed to download backup from Arweave"
  exit 1
fi

echo "Decrypting backup..."
age -d -i "$AGE_KEY_FILE" -o backup-restore.tar.gz "$BACKUP_FILE"

echo "Extracting backup..."
tar -xzf backup-restore.tar.gz

echo ""
echo "Backup contents:"
ls -la backups/

echo ""
echo "Metadata:"
cat backups/metadata.json | jq .

echo ""
echo "Available secret files:"
for f in backups/secrets*.json; do
  if [ -f "$f" ]; then
    COUNT=$(jq '. | length' "$f" 2>/dev/null || echo 0)
    echo "  $f: $COUNT secrets"
  fi
done

echo ""
echo "=============================================="
echo "To restore secrets to Infisical, you have two options:"
echo ""
echo "Option 1: Manual import via UI"
echo "  1. Go to https://secrets.alternatefutures.ai"
echo "  2. Navigate to your project"
echo "  3. Use Import from JSON feature"
echo ""
echo "Option 2: CLI import (for each path)"
echo "  infisical login --domain=https://secrets.alternatefutures.ai"
echo "  infisical secrets import --env=production --path=/shared backups/secrets__shared.json"
echo ""
echo "Option 3: API import (automated)"
echo "  See scripts/import-to-infisical.sh"
echo ""
echo "IMPORTANT: Verify ENCRYPTION_KEY matches before restoring!"
echo "If you've redeployed Infisical with a new ENCRYPTION_KEY,"
echo "the restored secrets will need to be re-encrypted."
echo "=============================================="

# Cleanup encrypted file
rm -f "$BACKUP_FILE"

echo ""
echo "Decrypted backup available in: ./backups/"
echo "Remember to delete after restore: rm -rf backups/ backup-restore.tar.gz"
