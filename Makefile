TARGET = crystal0
RELEASE_TARGET = $(TARGET)
DEBUG_TARGET = $(TARGET).debug
TARGETS = $(RELEASE_TARGET) $(DEBUG_TARGET)
SOURCES = src/$(TARGET).cr src/$(TARGET)/version.cr 
SPECS = spec/$(TARGET)_spec.cr src/spec_helper.cr
MAKEFILE = Makefile
DOCS = doc
LLDB_SCRIPT = .lldb_script

CRYSTALFLAGS = #--verbose
CRYSTALDEBUGFLAGS = --debug --stats -Ddebug
CRYSTALRELEASEFLAGS = --release
CRYSTALSPECFLAGS = --profile

CRYSTAL = crystal
LLDB = lldb
SED = sed

test: spec
spec: update_version $(SOURCES) $(MAKEFILE)
	@$(CRYSTAL) spec $(CRYSTALFLAGS) $(CRYSTALSPECFLAGS)

bump: _bump_patch_version update_version
bump_minor: _bump_minor_version update_version
bump_major: _bump_major_version update_version

_bump_patch_version:
	@$(SED) -i '' "s/^\(version:.*\)\.[0-9]*$$/\1.$$(($$($(MAKE) version | sed 's!^[0-9]*\.[0-9]*\.!!') + 1))/" shard.yml

_bump_minor_version:
	@$(SED) -i '' "s/^\(version:.*[0-9]\.\)[0-9]*\(\..*\)$$/\1$$(($$($(MAKE) version | sed 's!^[0-9]*\.!!;s!\.[0-9]*!!') + 1))\2/" shard.yml

_bump_major_version:
	@$(SED) -i '' "s/^\(version:[^0-9]*\)[0-9]*\(\..*\)/\1$$(($$($(MAKE) version | sed 's!\.[0-9]*\.[0-9]*!!') + 1))\2/" shard.yml

version:
	@$(SED) '/^version/!d;s/version: //' shard.yml

build: build_release
build_debug: $(DEBUG_TARGET)
build_release: $(RELEASE_TARGET)
update_version: src/$(TARGET)/version.cr shard.yml
src/$(TARGET)/version.cr: shard.yml
	@sed -i '' "s@\\(VERSION = \"\\).*\\(\".*\\)@\\1$$($(MAKE) version | tr '\n' '\0')\\2@" $@
	@echo Version now $$($(MAKE) version)

$(DEBUG_TARGET): update_version $(SOURCES) $(MAKEFILE)
	@$(CRYSTAL) build $(CRYSTALFLAGS) $(CRYSTALDEBUGFLAGS) $(SOURCES) -o $@

$(RELEASE_TARGET): update_version $(SOURCES) $(MAKEFILE)
	@$(CRYSTAL) build $(CRYSTALFLAGS) $(CRYSTALRELEASEFLAGS) $(SOURCES) -o $@

lldb_script: $(LLDB_SCRIPT)
$(LLDB_SCRIPT): Makefile
	@echo 'target create "$(DEBUG_TARGET)"' > $@
	@echo 'target stop-hook add' >> $@
	@echo 'up' >> $@
	@echo 'bt'  >> $@
	@echo 'DONE' >> $@
	@echo 'run' >> $@

rename: clean
	@if [ -z "$(NAME)" ]; then echo "make rename: NAME=new_name argument is missing"; false; fi
	@mv src/$(TARGET)/ src/$(NAME)/
	@find . \( -name README.md -o -name shard.yml -o -name Makefile -o -name '*.cr' \) | xargs -I% sed -i '' 's@$(TARGET)@$(NAME)@g' %
	@find . -name '*.cr' -exec sh -c 'mv "{}" $$(echo "{}" | sed "s@$(TARGET)@$(NAME)@g")' \;


debug: build_debug lldb_script
	@$(LLDB) -S $(LLDB_SCRIPT)

run: build_release
	@./$(TARGET)

clean_docs:
	rm -rf $(DOCS)

clean: clean_docs
	rm -rf $(TARGETS) $(LLDB_SCRIPT)

$(DOCS): clean_docs $(MAKEFILE)
	$(CRYSTAL) docs

rebuild: clean build
