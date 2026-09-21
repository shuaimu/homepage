# Build from any directory with: make -C teaching/db/26fa/slides
TYPST ?= typst
TYPST_FLAGS ?=
DECK := DB26fa-RocksDB
SOURCES := $(DECK).typ rocksdb-theme.typ rocksdb-diagrams.typ $(wildcard assets/*)

.PHONY: all
all: $(DECK).pdf $(DECK)-handout.pdf $(DECK).pdfpc

$(DECK).pdf: $(SOURCES)
	$(TYPST) compile $(TYPST_FLAGS) $(DECK).typ $@

$(DECK)-handout.pdf: $(SOURCES)
	$(TYPST) compile $(TYPST_FLAGS) --input handout=true $(DECK).typ $@

$(DECK).pdfpc: $(SOURCES) Makefile
	$(TYPST) eval $(TYPST_FLAGS) --in $(DECK).typ --pretty 'query(<pdfpc-file>).first().value' > $@
