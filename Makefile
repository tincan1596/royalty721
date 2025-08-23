.PHONY: anvilRun test clean

anvilRun:
	./script/anvilRun.sh

test:
	forge test -vvv

clean:
	rm -rf .anvil-state

anvilKill:
	pkill -f "^anvil" || true

anvilCheck:
	nc -z 127.0.0.1 8545 && echo "Anvil is up" || echo "Anvil is down"