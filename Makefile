SRCDIR ?= .
OUTDIR ?= generated

DEFAULTS ?= $(wildcard $(SRCDIR)/defaults.yaml)
METADATA ?= $(wildcard $(SRCDIR)/metadata.yaml)

override PAPER_SRC := $(wildcard $(SRCDIR)/P*.md)
override SLIDES_SRC := $(wildcard $(SRCDIR)/slides-*.md)

override PAPERS := $(PAPER_SRC:.md=.html)
override SLIDES := $(SLIDES_SRC:.md=.pdf)

override ROOTDIR := $(dir $(lastword $(MAKEFILE_LIST)))

override DEPSDIR := $(ROOTDIR)deps

override PYTHON_BIN := /usr/bin/python

export SHELL := bash

override DATADIR := $(ROOTDIR)data

override define PANDOC
$(eval override FILE := $(filter %.md, $^))
$(eval override CMD := pandoc $(FILE) -o $@ -d $(DATADIR)/defaults.yaml)
$(eval $(and $(DEFAULTS), override CMD += -d $(DEFAULTS)))
$(eval $(and $(METADATA), override CMD += --metadata-file $(METADATA)))
$(if $(filter %.html, $@),
  $(eval override TOCDEPTH := $(shell $(PYTHON_BIN) $(DATADIR)/toc-depth.py < $(FILE)))
  $(eval $(and $(TOCDEPTH), override CMD += --toc-depth $(TOCDEPTH))))
$(CMD)
endef

override DEPS := $(addprefix $(DATADIR)/, defaults.yaml csl.json annex-f)
$(eval $(and $(DEFAULTS), override DEPS += $(DEFAULTS)))
$(eval $(and $(METADATA), override DEPS += $(METADATA)))

.PHONY: all
all: $(PAPERS) $(SLIDES)

.PHONY: clean
clean:
	rm -rf $(DEPS) $(OUTDIR)

.PHONY: $(PAPERS)
$(PAPERS): $(SRCDIR)/%: $(OUTDIR)/%

.PHONY: $(SLIDES)
$(SLIDES): $(SRCDIR)/%: $(OUTDIR)/%

.PHONY: update
update:
	@$(MAKE) --always-make $(DATADIR)/csl.json $(DATADIR)/annex-f

$(OUTDIR):
	mkdir -p $@

$(DATADIR)/defaults.yaml: $(DATADIR)/defaults.sh
	DATADIR=$(abspath $(DATADIR)) $< > $@

$(DATADIR)/csl.json: $(DATADIR)/refs.py
	$(PYTHON_BIN) $< > $@

$(DATADIR)/annex-f:
	curl -sSL https://timsong-cpp.github.io/cppwp/annex-f -o $@

$(OUTDIR)/P%.html: $(SRCDIR)/P%.md $(DEPS) | $(OUTDIR)
	$(PANDOC) --bibliography $(DATADIR)/csl.json

$(OUTDIR)/slides-%.pdf: $(SRCDIR)/slides-%.md $(DEPS) | $(OUTDIR)
	$(PANDOC) -t beamer --bibliography $(DATADIR)/csl.json

