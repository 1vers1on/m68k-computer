IVERILOG := iverilog
VVP := vvp
BUILD_DIR := .build
RTL_DIR := rtl
TEST_DIR := test

RTL_FILES := $(shell find $(RTL_DIR) -type f -name '*.sv' | sort)
TB_FILES := $(shell find $(TEST_DIR) -type f -name 'tb_*.sv' | sort)
TESTS := $(foreach f,$(TB_FILES),$(patsubst tb_%.sv,%,$(notdir $(f))))

$(foreach f,$(TB_FILES),$(eval TB_$(patsubst tb_%.sv,%,$(notdir $(f))) := $(f)))

.DEFAULT_GOAL := all
.PHONY: help all test list clean $(TESTS)

help:
	@echo "SystemVerilog simulation commands:"
	@echo "  make test              Run every testbench"
	@echo "  make test NAME=decoder Run one testbench"
	@echo "  make list              List available test names"
	@echo "  make clean             Remove generated simulation output"

all: test

test: $(if $(NAME),$(NAME),$(TESTS))

list:
	@$(foreach test,$(TESTS),echo $(test);)

$(TESTS): %: | $(BUILD_DIR)
	@rm -f $(BUILD_DIR)/$*.out $(BUILD_DIR)/$*.log
	@$(IVERILOG) -g2012 -gspecify -o $(BUILD_DIR)/$*.out -s tb_$* $(TB_$*) $(RTL_FILES) > $(BUILD_DIR)/$*.log 2>&1; \
	$(VVP) $(BUILD_DIR)/$*.out >> $(BUILD_DIR)/$*.log 2>&1; \
	if grep -q "PASS " $(BUILD_DIR)/$*.log; then echo "PASS  $*"; else echo "FAIL  $*"; cat $(BUILD_DIR)/$*.log; exit 1; fi

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)
