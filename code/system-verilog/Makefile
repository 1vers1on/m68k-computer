IVERILOG := iverilog
VVP := vvp
IVERILOG_FLAGS := -g2012 -gspecify
BUILD_DIR := .build
RTL_DIR := rtl
TEST_DIR := test

RTL_FILES := $(shell find $(RTL_DIR) -type f -name '*.sv' | sort)
TB_FILES := $(shell find $(TEST_DIR) -type f -name 'tb_*.sv' | sort)
TESTS := $(foreach f,$(TB_FILES),$(patsubst tb_%.sv,%,$(notdir $(f))))

$(foreach f,$(TB_FILES),$(eval TB_$(patsubst tb_%.sv,%,$(notdir $(f))) := $(f)))

.DEFAULT_GOAL := all
.PHONY: help all test check test-runner list clean invalid-name $(TESTS)

help:
	@echo "SystemVerilog simulation commands:"
	@echo "  make test              Run every testbench"
	@echo "  make test NAME=decoder Run one testbench"
	@echo "  make check             Run simulations and runner regression tests"
	@echo "  make test-runner       Check the runner with Python 3"
	@echo "  make list              List available test names"
	@echo "  make clean             Remove generated simulation output"

all: test

check: test test-runner

test-runner:
	python3 -m unittest discover -s test -p 'test_*.py'

test: $(if $(filter-out $(TESTS),$(NAME)),invalid-name,$(if $(NAME),$(NAME),$(TESTS)))

invalid-name:
	@echo "Unknown test name: $(filter-out $(TESTS),$(NAME)). Run make list for available tests." >&2
	@exit 1

list:
	@$(foreach test,$(TESTS),echo $(test);)

$(TESTS): %: | $(BUILD_DIR)
	@rm -f $(BUILD_DIR)/$*.out $(BUILD_DIR)/$*.log
	@if $(IVERILOG) $(IVERILOG_FLAGS) -o $(BUILD_DIR)/$*.out -s tb_$* $(TB_$*) $(RTL_FILES) > $(BUILD_DIR)/$*.log 2>&1 && \
	    $(VVP) $(BUILD_DIR)/$*.out >> $(BUILD_DIR)/$*.log 2>&1 && \
	    grep -q '^[[:space:]]*PASS[[:space:]]' $(BUILD_DIR)/$*.log && \
	    ! grep -Eq '^[[:space:]]*(FAIL|FATAL|ERROR)([[:space:]]|:)' $(BUILD_DIR)/$*.log; then \
	    echo "PASS  $*"; \
	else \
	    echo "FAIL  $*"; cat $(BUILD_DIR)/$*.log; exit 1; \
	fi

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)
