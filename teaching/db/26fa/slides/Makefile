# Build from any directory with: make -C teaching/db/26fa/slides
# One deck: make -C teaching/db/26fa/slides queryopt (or rocksdb, spannersql)
# HTML player of one deck: make -C teaching/db/26fa/slides queryopt-export
# PowerPoint copy, built only on request: make -C teaching/db/26fa/slides DB26fa-QueryOpt.pptx
TYPST ?= typst
TYPST_FLAGS ?=
PYTHON ?= python3

DECKS := DB26fa-RocksDB DB26fa-QueryOpt DB26fa-SpannerSQL
DB26fa-RocksDB_DEPS := rocksdb-theme.typ rocksdb-diagrams.typ
DB26fa-QueryOpt_DEPS := queryopt-theme.typ queryopt-diagrams.typ
DB26fa-SpannerSQL_DEPS := spannersql-theme.typ spannersql-diagrams.typ
ASSETS := $(wildcard assets/*)

.PHONY: all rocksdb queryopt spannersql rocksdb-export queryopt-export spannersql-export
all: $(foreach d,$(DECKS),$(d).pdf $(d)-handout.pdf $(d).pdfpc)
rocksdb: DB26fa-RocksDB.pdf DB26fa-RocksDB-handout.pdf DB26fa-RocksDB.pdfpc
queryopt: DB26fa-QueryOpt.pdf DB26fa-QueryOpt-handout.pdf DB26fa-QueryOpt.pdfpc
spannersql: DB26fa-SpannerSQL.pdf DB26fa-SpannerSQL-handout.pdf DB26fa-SpannerSQL.pdfpc
rocksdb-export: DB26fa-RocksDB.html
queryopt-export: DB26fa-QueryOpt.html
spannersql-export: DB26fa-SpannerSQL.html

# Presentation PDF, handout PDF, and pdfpc sidecar for one deck.
# Each deck depends on its own theme and diagram modules; adding a deck means
# adding its name to DECKS and one <name>_DEPS line above.
define DECK_RULES
$(1).pdf: $(1).typ $$($(1)_DEPS) $$(ASSETS)
	$$(TYPST) compile $$(TYPST_FLAGS) $$< $$@

$(1)-handout.pdf: $(1).typ $$($(1)_DEPS) $$(ASSETS)
	$$(TYPST) compile $$(TYPST_FLAGS) --input handout=true $$< $$@

$(1).pdfpc: $(1).typ $$($(1)_DEPS) $$(ASSETS) Makefile
	$$(TYPST) eval $$(TYPST_FLAGS) --in $$< --pretty 'query(<pdfpc-file>).first().value' > $$@

# The exports read the overlay groups and notes from the pdfpc file and the slide
# titles from the PDF, so they follow both.
$(1).html $(1).pptx: $(1).%: $(1).pdf $(1).pdfpc export-deck.py
	TYPST='$$(TYPST)' TYPST_FLAGS='$$(TYPST_FLAGS)' $$(PYTHON) export-deck.py $$* $(1)
endef
$(foreach d,$(DECKS),$(eval $(call DECK_RULES,$(d))))
