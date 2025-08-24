.PHONY: anvilRun test clean kill status

anvilRun:
	./script/anvilRun.sh

test:
	forge test -vvv --fork-url ${ANVIL_MAINNET} --match-path "test/fork/*"

clean:
	rm -rf .anvil

kill:
	pkill -f "^anvil" || true

status:
	nc -z 127.0.0.1 8545 && echo "Anvil is up" || echo "Anvil is down"