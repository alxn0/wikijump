.PHONY: test

VIM ?= vim
TESTS := $(wildcard tests/test_*.vim)

test:
	@rm -f tmp/test.log
	@$(VIM) -es -Nu NONE -S tests/runtest.vim $(TESTS) </dev/null; \
		status=$$?; \
		cat tmp/test.log 2>/dev/null || echo "(no log produced)"; \
		exit $$status
