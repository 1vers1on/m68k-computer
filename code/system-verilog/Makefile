IVERILOG := iverilog
VVP := vvp
OUT_DIR := .build

TB_FILES := $(shell find . -type f -name 'tb_*.sv' -not -path './$(OUT_DIR)/*')
SRC_FILES := $(shell find . -type f -name '*.sv' -not -name 'tb_*.sv' -not -path './$(OUT_DIR)/*')
TESTS := $(foreach f,$(TB_FILES),$(patsubst tb_%.sv,%,$(notdir $(f))))
RESULTS := $(addprefix $(OUT_DIR)/,$(TESTS))

$(foreach f,$(TB_FILES),$(eval TB_$(patsubst tb_%.sv,%,$(notdir $(f))) := $(f)))

.PHONY: all test clean

all: $(RESULTS)

test:
	@$(MAKE) -s $(if $(NAME),-B $(OUT_DIR)/$(NAME),all)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

$(OUT_DIR)/%: $(SRC_FILES) | $(OUT_DIR)
	@rm -f $@.out; \
	$(IVERILOG) -g2012 -gspecify -o $@.out -s tb_$* $(TB_$*) $(SRC_FILES) > $@.log 2>&1; \
	$(VVP) $@.out >> $@.log 2>&1; \
	if grep -q "PASS " $@.log; then echo "PASS  $*"; touch $@; else echo "FAIL  $*"; cat $@.log; exit 1; fi

clean:
	rm -rf $(OUT_DIR)
