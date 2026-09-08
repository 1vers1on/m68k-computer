IVERILOG := iverilog
VVP := vvp
TB_DIR := tb
SRC_DIR := src/models
OUT_DIR := .build

TB_FILES := $(wildcard $(TB_DIR)/tb_*.sv)
SRC_FILES := $(wildcard $(SRC_DIR)/*.sv)
TESTS := $(patsubst $(TB_DIR)/tb_%.sv,%,$(TB_FILES))
RESULTS := $(addprefix $(OUT_DIR)/,$(TESTS))

.PHONY: all test clean

all: $(RESULTS)

test:
	@$(MAKE) -s $(if $(NAME),-B $(OUT_DIR)/$(NAME),all)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

$(OUT_DIR)/%: $(TB_DIR)/tb_%.sv $(SRC_FILES) | $(OUT_DIR)
	@rm -f $@.out; \
	$(IVERILOG) -g2012 -gspecify -o $@.out -s tb_$* $(TB_DIR)/tb_$*.sv $(SRC_FILES) > $@.log 2>&1; \
	$(VVP) $@.out >> $@.log 2>&1; \
	if grep -q "PASS " $@.log; then echo "PASS  $*"; touch $@; else echo "FAIL  $*"; cat $@.log; exit 1; fi

clean:
	rm -rf $(OUT_DIR)
