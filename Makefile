.PHONY: anvilRun test clean

anvilRun:
	./scripts/anvilRun.sh

test:
	forge test -vvv

clean:
	rm -rf .anvil-state
