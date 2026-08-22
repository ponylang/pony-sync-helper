config ?= release

GET_DEPENDENCIES_WITH := corral fetch
CLEAN_DEPENDENCIES_WITH := corral clean
COMPILE_WITH := corral run -- ponyc
LINT_WITH := corral run -- pony-lint

BUILD_DIR ?= build/$(config)
binary := $(BUILD_DIR)/pony-sync-helper

ifdef config
  ifeq (,$(filter $(config),debug release))
    $(error Unknown configuration "$(config)")
  endif
endif

ifeq ($(config),release)
	PONYC = $(COMPILE_WITH)
else
	PONYC = $(COMPILE_WITH) --debug
endif

ifeq (,$(filter $(MAKECMDGOALS),clean lint realclean TAGS))
  ifeq ($(ssl), 3.0.x)
    SSL = -Dopenssl_3.0.x
  else ifeq ($(ssl), 1.1.x)
    SSL = -Dopenssl_1.1.x
  else ifeq ($(ssl), libressl)
    SSL = -Dlibressl
  else
    $(error Unknown SSL version "$(ssl)". Must set using 'ssl=FOO')
  endif
endif

PONYC := $(PONYC) $(SSL)

SOURCE_FILES := $(shell find . -name "*.pony" -not -path "./_corral/*")

build: $(binary)

$(binary): $(SOURCE_FILES) | $(BUILD_DIR) fetch
	$(PONYC) -o $(BUILD_DIR)

fetch:
	$(GET_DEPENDENCIES_WITH)

lint:
	$(GET_DEPENDENCIES_WITH)
	$(LINT_WITH) .

clean:
	$(CLEAN_DEPENDENCIES_WITH)
	rm -rf build

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

.PHONY: build clean fetch lint
