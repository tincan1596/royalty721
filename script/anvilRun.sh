#!/usr/bin/env bash
set -euo pipefail

STATE_FILE=".anvil/${CHAIN:-mainnet}-${BLOCK_NUMBER:-23226000}.json"


echo "  Starting Anvil fork:"
echo "  Chain:        ${CHAIN:-mainnet}"
echo "  Block number: ${BLOCK_NUMBER:-23226000}"
echo "  State file:   $STATE_FILE"

mkdir -p .anvil

anvil \
  --fork-url "${FORK_URL:-${MAINNET_RPC_URL}}" \
  --fork-block-number "${BLOCK_NUMBER:-23226000}" \
  --state "$STATE_FILE" \
  --port "${PORT:-8545}" \
  --chain-id "${CHAIN_ID:-1}" \
  --silent
