.DEFAULT_GOAL := help
.PHONY: help install test check format clean

help:
	@echo "make install   Install dependencies from package-lock.json"
	@echo "make check     Check HTML formatting (also make test)"
	@echo "make format    Format HTML pages"

install:
	npm ci

test: check

check:
	npm run format:check

format:
	npm run format

clean:
	@echo "Documentation is served from source; there is no generated output to clean."
