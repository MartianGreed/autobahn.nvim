.PHONY: test test-watch

test:
	nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.vim'}"

test-watch:
	find lua/ tests/ -name '*.lua' | entr -c make test

help:
	@echo "Available targets:"
	@echo "  test        - Run all tests"
	@echo "  test-watch  - Run tests on file change (requires entr)"
