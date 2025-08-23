#!/usr/bin/env bash
set -euo pipefail

# Load env vars if .env exists
[ -f .env ] && export $(grep -v '^#' .env | xargs)

# Defaults if not set
: "${CHAIN:=mainnet}"
: "${BLOCK_NUMBER:=18000000}"

STATE_FILE=".anvil-state/${CHAIN}-${BLOCK_NUMBER}.json"

echo "  Starting Anvil fork:"
echo "  Chain:        $CHAIN"
echo "  Block number: $BLOCK_NUMBER"
echo "  State file:   $STATE_FILE"

anvil \
  --fork-url "$MAINNET_RPC_URL" \
  --fork-block-number "$BLOCK_NUMBER" \
  --state "$STATE_FILE" \
  --port 8545 --chain-id 1 --silent
