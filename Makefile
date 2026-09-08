.DEFAULT_GOAL := help

PROJECTS := $(patsubst %/Makefile,%,$(sort $(wildcard */Makefile */*/Makefile)))
SELECTED_PROJECTS := $(if $(strip $(PROJECT)),$(PROJECT),$(PROJECTS))
UNKNOWN_PROJECTS := $(filter-out $(PROJECTS),$(SELECTED_PROJECTS))

ifneq ($(strip $(UNKNOWN_PROJECTS)),)
$(error Unknown project: $(UNKNOWN_PROJECTS). Run make list for available projects)
endif

.PHONY: help list docs-install docs-check docs-format

help:
	@echo "make list                  List available projects"
	@echo "make test                  Run each project's tests"
	@echo "make check                 Run each project's checks"
	@echo "make clean                 Remove each project's generated output"
	@echo "Add PROJECT=path to select a project."
	@echo "make docs-install          Install documentation dependencies"
	@echo "make docs-check            Check documentation formatting"
	@echo "make docs-format           Format documentation"

list:
	@$(foreach project,$(PROJECTS),echo $(project);)

# Each project owns its toolchain and implements these targets locally.
define project_targets
.PHONY: $(1) $(addprefix $(1)/,$(SELECTED_PROJECTS))
$(1): $(addprefix $(1)/,$(SELECTED_PROJECTS))
$(addprefix $(1)/,$(SELECTED_PROJECTS)):
	$$(MAKE) -C $$(patsubst $(1)/%,%,$$@) $(1)
endef

$(foreach target,test check clean,$(eval $(call project_targets,$(target))))

docs-install:
	$(MAKE) -C docs install

docs-check:
	$(MAKE) -C docs check

docs-format:
	$(MAKE) -C docs format
