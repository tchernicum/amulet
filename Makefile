include Common.mk

MAIN_TARGET = $(AMULET)

# Build settings

AM_DEFS = AM_$(shell echo $(TARGET_PLATFORM) | tr a-z A-Z) AM_$(shell echo $(GRADE) | tr a-z A-Z)

ifeq ($(LUAVM),luajit)
  AM_DEFS += AM_LUAJIT
else ifeq ($(LUAVM),lua51)
  AM_DEFS += AM_LUA51
else ifeq ($(LUAVM),lua52)
  AM_DEFS += AM_LUA52
else ifeq ($(LUAVM),lua53)
  AM_DEFS += AM_LUA53
else
  $(error invalid LUAVM: $(LUAVM))
endif

AMULET = $(BUILD_BIN_DIR)/amulet$(EXE_EXT)

EXTRA_PREREQS = 

SDL_PREBUILT = $(SDL_PREBUILT_DIR)/sdl-prebuilt.date

ifeq ($(TARGET_PLATFORM),html)
  AM_DEPS = $(LUAVM) stb kissfft
  AMULET = $(BUILD_BIN_DIR)/amulet.html
else ifdef IOS
  AM_DEPS = $(LUAVM) stb kissfft
else ifeq ($(TARGET_PLATFORM),msvc32)
  AM_DEPS = $(LUAVM) stb kissfft ft2
  EXTRA_PREREQS = $(SDL_PREBUILT) $(ANGLE_WIN_PREBUILT) $(SIMPLEGLOB_H)
else ifeq ($(TARGET_PLATFORM),mingw32)
  AM_DEPS = $(LUAVM) stb kissfft ft2
  EXTRA_PREREQS = $(SDL_PREBUILT) $(ANGLE_WIN_PREBUILT) $(SIMPLEGLOB_H)
else
  AM_DEPS = $(LUAVM) sdl angle stb kissfft ft2
  AM_DEFS += AM_USE_ANGLE
  EXTRA_PREREQS = $(SIMPLEGLOB_H)
endif

DEP_ALIBS = $(patsubst %,$(BUILD_LIB_DIR)/lib%$(ALIB_EXT),$(AM_DEPS))

VIEW_TEMPLATES = $(wildcard $(SRC_DIR)/am*view_template.inc)

VERSION_CPP_FILE = $(SRC_DIR)/am_version.cpp

EMBEDDED_LUA_FILES = $(wildcard lua/*.lua)
EMBEDDED_PNGS = $(wildcard lua/*.png)
EMBEDDED_FILES = $(EMBEDDED_LUA_FILES) $(EMBEDDED_PNGS)
EMBEDDED_DATA_CPP_FILE = $(SRC_DIR)/am_embedded_data.cpp

AM_CPP_FILES = $(sort $(wildcard $(SRC_DIR)/*.cpp) $(EMBEDDED_DATA_CPP_FILE) $(VERSION_CPP_FILE))
AM_H_FILES = $(wildcard $(SRC_DIR)/*.h)
AM_OBJ_FILES = $(patsubst $(SRC_DIR)/%.cpp,$(BUILD_OBJ_DIR)/%$(OBJ_EXT),$(AM_CPP_FILES))

AM_INCLUDE_FLAGS = $(INCLUDE_OPT)$(BUILD_INC_DIR) \
	$(INCLUDE_OPT)$(GLM_DIR)

AM_DEF_FLAGS=$(patsubst %,$(DEF_OPT)%,$(AM_DEFS))

AM_CFLAGS = $(AM_DEF_FLAGS) $(LUA_CFLAGS) $(XCFLAGS) $(AM_INCLUDE_FLAGS) $(COMMON_CFLAGS) 
AM_LDFLAGS = $(GRADE_LDFLAGS) $(DEP_ALIBS) $(XLDFLAGS) $(LDFLAGS)

EXAMPLE_FILES := $(wildcard examples/*.lua)
BUILD_EXAMPLE_FILES := $(patsubst examples/%,$(BUILD_BIN_DIR)/%,$(EXAMPLE_FILES))
HTML_EDITOR_FILES := $(wildcard html/*.js html/*.css html/*.html html/*.ico)
BUILD_HTML_EDITOR_FILES := $(patsubst html/%,$(BUILD_BIN_DIR)/%,$(HTML_EDITOR_FILES))

# Rules

default: all

.PHONY: all
ifeq ($(TARGET_PLATFORM),html)
all: $(BUILD_HTML_EDITOR_FILES) $(BUILD_EXAMPLE_FILES) $(AMULET) 
else
all: $(AMULET)
endif

ifeq ($(TARGET_PLATFORM),html)
$(AMULET): $(DEP_ALIBS) $(AM_OBJ_FILES) $(EMSCRIPTEN_LIBS) | $(BUILD_BIN_DIR) 
	$(LINK) $(AM_OBJ_FILES) $(AM_LDFLAGS) $(EXE_OUT_OPT)$@
	@$(PRINT_BUILD_DONE_MSG)
else ifdef IOS
# Just build the static library for iOS. Building the executable works,
# but I don't know how to import that into Xcode.
$(AMULET): $(DEP_ALIBS) $(AM_OBJ_FILES) $(EXTRA_PREREQS) | $(BUILD_BIN_DIR)
	rm -f $(AR_OUT_OPT)$@$(ALIB_EXT)
	$(AR) $(AR_OPTS) $(AR_OUT_OPT)$@$(ALIB_EXT) $(AM_OBJ_FILES) 
	@$(PRINT_BUILD_DONE_MSG)
else ifdef WINDOWS
# build both console and windows versions
$(AMULET): $(DEP_ALIBS) $(AM_OBJ_FILES) $(EXTRA_PREREQS) | $(BUILD_BIN_DIR)
	$(LINK) $(CONSOLE_SUBSYSTEM_OPT) $(AM_OBJ_FILES) $(AM_LDFLAGS) $(EXE_OUT_OPT)$(BUILD_BIN_DIR)/amulet-console.exe
	$(LINK) $(WINDOWS_SUBSYSTEM_OPT) $(AM_OBJ_FILES) $(AM_LDFLAGS) $(EXE_OUT_OPT)$@
	cp $(BUILD_BIN_DIR)/* .
	@$(PRINT_BUILD_DONE_MSG)
else
$(AMULET): $(DEP_ALIBS) $(AM_OBJ_FILES) $(EXTRA_PREREQS) | $(BUILD_BIN_DIR)
	$(LINK) $(AM_OBJ_FILES) $(AM_LDFLAGS) $(EXE_OUT_OPT)$@
	rm -f `basename $@` && cp $@ `basename $@`
	@$(PRINT_BUILD_DONE_MSG)
endif

$(AM_OBJ_FILES): $(BUILD_OBJ_DIR)/%$(OBJ_EXT): $(SRC_DIR)/%.cpp $(AM_H_FILES) | $(BUILD_OBJ_DIR) $(EXTRA_PREREQS)
	$(CPP) $(AM_CFLAGS) $(NOLINK_OPT) $< $(OBJ_OUT_OPT)$@

$(BUILD_OBJ_DIR)/am_buffer$(OBJ_EXT): $(SRC_DIR)/am_generated_view_defs.inc $(VIEW_TEMPLATES)

$(SDL_ALIB): | $(BUILD_LIB_DIR) $(BUILD_INC_DIR)
	if [ -d $(SDL_PREBUILT_DIR) ]; then \
	    cp $(SDL_PREBUILT_DIR)/lib/*.a $(BUILD_LIB_DIR)/; \
	    cp -r $(SDL_DIR)/include/* $(BUILD_INC_DIR)/; \
	    cp -r $(SDL_PREBUILT_DIR)/include/* $(BUILD_INC_DIR)/; \
	else \
	    pushd $(SDL_DIR) && ./configure --disable-render --disable-loadso CC=$(CC) CXX=$(CPP) CFLAGS="$(COMMON_CFLAGS)" LDFLAGS="$(LDFLAGS)" && $(MAKE) clean && $(MAKE); \
	    popd; \
	    cp -r $(SDL_DIR)/include/* $(BUILD_INC_DIR)/; \
	    cp $(SDL_DIR)/build/.libs/libSDL2$(ALIB_EXT) $@; \
	fi

$(SDL_PREBUILT): | $(BUILD_LIB_DIR) $(BUILD_INC_DIR) $(BUILD_BIN_DIR)
	cp -r $(SDL_PREBUILT_DIR)/include/* $(BUILD_INC_DIR)/
	-cp $(SDL_PREBUILT_DIR)/lib/*.lib $(BUILD_LIB_DIR)/
	-cp $(SDL_PREBUILT_DIR)/lib/*.dll $(BUILD_LIB_DIR)/
	-cp $(SDL_PREBUILT_DIR)/lib/*.a $(BUILD_LIB_DIR)/
	touch $@

$(ANGLE_ALIB): | $(BUILD_LIB_DIR) $(BUILD_INC_DIR)
	cd $(ANGLE_DIR) && $(MAKE) clean
	cd $(ANGLE_DIR) && $(MAKE) all
	cp $(ANGLE_DIR)/libangle$(ALIB_EXT) $@
	cp -r $(ANGLE_DIR)/include/GLSLANG $(BUILD_INC_DIR)/
	cp -r $(ANGLE_DIR)/include/KHR $(BUILD_INC_DIR)/

$(ANGLE_WIN_PREBUILT): | $(BUILD_LIB_DIR) $(BUILD_INC_DIR) $(BUILD_BIN_DIR)
	cp -r $(ANGLE_WIN_PREBUILT_DIR)/include/* $(BUILD_INC_DIR)/
	cp $(ANGLE_WIN_PREBUILT_DIR)/lib/*.dll $(BUILD_BIN_DIR)/
	touch $@

$(LUA51_ALIB): | $(BUILD_LIB_DIR) $(BUILD_INC_DIR)
	cd $(LUA51_DIR) && $(MAKE) -f Makefile.custom clean
	cd $(LUA51_DIR) && $(MAKE) -f Makefile.custom all
	cp $(LUA51_DIR)/src/*.h $(BUILD_INC_DIR)/
	cp $(LUA51_DIR)/src/liblua$(ALIB_EXT) $@

$(LUA52_ALIB): | $(BUILD_LIB_DIR) $(BUILD_INC_DIR)
	cd $(LUA52_DIR) && $(MAKE) -f Makefile.custom clean
	cd $(LUA52_DIR) && $(MAKE) -f Makefile.custom all
	cp $(LUA52_DIR)/src/*.h $(BUILD_INC_DIR)/
	cp $(LUA52_DIR)/src/liblua$(ALIB_EXT) $@

$(LUA53_ALIB): | $(BUILD_LIB_DIR) $(BUILD_INC_DIR)
	cd $(LUA53_DIR) && $(MAKE) -f Makefile.custom clean
	cd $(LUA53_DIR) && $(MAKE) -f Makefile.custom all
	cp $(LUA53_DIR)/src/*.h $(BUILD_INC_DIR)/
	cp $(LUA53_DIR)/src/liblua$(ALIB_EXT) $@

$(LUAJIT_ALIB): | $(BUILD_LIB_DIR) $(BUILD_INC_DIR)
	cd $(LUAJIT_DIR) && $(MAKE) clean $(LUAJIT_FLAGS)
	cd $(LUAJIT_DIR) && $(MAKE) all $(LUAJIT_FLAGS)
	cp $(LUAJIT_DIR)/src/*.h $(BUILD_INC_DIR)/
	cp $(LUAJIT_DIR)/src/libluajit$(ALIB_EXT) $@

$(FT2_ALIB): | $(BUILD_LIB_DIR) $(BUILD_INC_DIR)
	cd $(FT2_DIR) && $(MAKE) -f Makefile.custom clean
	cd $(FT2_DIR) && $(MAKE) -f Makefile.custom all
	cp $(FT2_DIR)/libft2$(ALIB_EXT) $@
	cp -r $(FT2_DIR)/include/* $(BUILD_INC_DIR)/

$(STB_ALIB): | $(BUILD_LIB_DIR) $(BUILD_INC_DIR)
	cd $(STB_DIR) && $(MAKE) clean
	cd $(STB_DIR) && $(MAKE) all
	cp $(STB_DIR)/libstb$(ALIB_EXT) $@
	cp $(STB_DIR)/*.h $(BUILD_INC_DIR)/
	cp $(STB_DIR)/*.c $(BUILD_INC_DIR)/

$(SIMPLEGLOB_H): | $(BUILD_INC_DIR)
	cp $(SIMPLEOPT_DIR)/SimpleGlob.h $@

$(KISSFFT_ALIB): | $(BUILD_LIB_DIR) $(BUILD_INC_DIR)
	cd $(KISSFFT_DIR) && $(MAKE) -f Makefile.custom clean
	cd $(KISSFFT_DIR) && $(MAKE) -f Makefile.custom all
	cp $(KISSFFT_DIR)/libkissfft$(ALIB_EXT) $@
	cp $(KISSFFT_DIR)/kiss_fft.h $(BUILD_INC_DIR)/
	cp $(KISSFFT_DIR)/kiss_fftr.h $(BUILD_INC_DIR)/

$(BUILD_DIRS): %:
	mkdir -p $@

$(BUILD_HTML_EDITOR_FILES): $(BUILD_BIN_DIR)/%: html/% | $(BUILD_BIN_DIR)
	cp $< $@

$(BUILD_EXAMPLE_FILES): $(BUILD_BIN_DIR)/%: examples/% | $(BUILD_BIN_DIR)
	cp $< $@

# View templates

tools/gen_view_defs$(EXE_EXT): tools/gen_view_defs.c
	$(HOSTCC) -o $@ $<

$(SRC_DIR)/am_generated_view_defs.inc: tools/gen_view_defs$(EXE_EXT)
	tools/gen_view_defs$(EXE_EXT) > $@

# Embedded Lua code

tools/embed$(EXE_EXT): tools/embed.c
	$(HOSTCC) -o $@ $<

$(EMBEDDED_DATA_CPP_FILE): $(EMBEDDED_FILES) tools/embed$(EXE_EXT)
	tools/embed$(EXE_EXT) $(EMBEDDED_FILES) > $@

# Generate version file

ifdef TRAVIS_TAG
VERSION = $(TRAVIS_TAG)
else ifdef APPVEYOR_REPO_TAG_NAME
VERSION = $(APPVEYOR_REPO_TAG_NAME)
else
VERSION = $(shell echo DEV `date '+%Y-%d-%m %H:%M'`)
endif

$(VERSION_CPP_FILE):
	echo "const char *am_version = \"$(VERSION)\";" > $@

# Font generation tool

tools/ampack$(EXE_EXT): tools/ampack.c $(FT2_ALIB)
	$(CC) $(COMMON_CFLAGS) $(NOLINK_OPT) $(AM_INCLUDE_FLAGS) $(OBJ_OUT_OPT)tools/ampack$(OBJ_EXT) $<
	$(LINK) tools/ampack$(OBJ_EXT) $(FT2_ALIB) $(XLDFLAGS) $(EXE_OUT_OPT)$@
	cp $@ `basename $@`

# runnable gl logs (assumes gllog.cpp exists)

gllog: gllog.cpp $(DEP_ALIBS) $(EXTRA_PREREQS) | $(BUILD_BIN_DIR)
	$(CPP) $(AM_CFLAGS) $(NOLINK_OPT) $< $(OBJ_OUT_OPT)gllog.o
	$(LINK) gllog.o $(AM_LDFLAGS) -lGL $(EXE_OUT_OPT)$@

# Cleanup

clean:
	rm -f $(BUILD_OBJ_DIR)/*
	rm -f $(BUILD_BIN_DIR)/*
	rm -f $(EMBEDDED_DATA_CPP_FILE)
	rm =f $(VERSION_CPP_FILE)
	rm -f amulet$(EXE_EXT)

clean-target:
	rm -rf builds/$(TARGET_PLATFORM)/$(GRADE)

clean-all: clean-tests
	rm -rf builds
	rm -f amulet$(EXE_EXT)

# Docs

.PHONY: doc
doc: $(AMULET)
	cd doc && $(MAKE)

# Tests

LUA_TESTS = $(patsubst tests/test_%.lua,test_%,$(wildcard tests/test_*.lua))

.PHONY: test
test: run_lua_tests

.PHONY: run_lua_tests
run_lua_tests: $(AMULET)
	@echo Running Lua tests...
	@for t in $(LUA_TESTS); do \
	    flua=tests/$$t.lua; \
	    fexp=tests/$$t.exp; \
	    fexp2=tests/$$t.exp2; \
	    fout=tests/$$t.out; \
	    fres=tests/$$t.res; \
	    haswindow=`grep "am\.window" $$flua`; \
	    if [ -n "$(TRAVIS)" -a -n "$$haswindow" ]; then \
		printf "%-30s%s       %s\n" "$$t" "skipped"; \
	    else \
		$(AMULET) $$flua > $$fout 2>&1 ; \
		if ( diff -u $$fexp $$fout > $$fres ) || ( [ -e $$fexp2 ] && ( diff -u $$fexp2 $$fout > $$fres ) ); then \
		    printf "%-30s%s       %s\n" "$$t" "pass"; \
		else \
		    cat $$fres;	\
		    echo "$$t **FAIL**"; \
		    exit 1;		\
		fi; \
	    fi; \
	done
	@echo DONE

clean-tests:
	rm -f tests/*.out
	rm -f tests/*.res
	rm -f tests/*.err

# Avoid setting options or variables in submakes,
# because setting TARGET messes up the SDL build.
MAKEOVERRIDES =
unexport

# Banner
PRINT_BUILD_DONE_MSG = \
  echo -------- Amulet build successful ------; \
  echo TARGET_PLATFORM:    $(TARGET_PLATFORM); \
  echo HOST_PLATFORM:      $(HOST_PLATFORM); \
  echo GRADE:              $(GRADE); \
  echo CC:                 $(CC); \
  echo CPP:                $(CPP); \
  echo DEPS:               $(AM_DEPS); \
  echo ---------------------------------------;

# Tags
.PHONY: tags
tags:
	ctags `find $(SRC_DIR) -name "*.h"` `find $(SRC_DIR) -name "*.cpp"`
