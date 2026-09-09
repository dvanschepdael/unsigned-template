.DEFAULT_GOAL := all
SHELL := /bin/bash
.DELETE_ON_ERROR:

BUILDDIR := build
GAMEROM := unsigned-template
GAMETITLE := Unsigned template
NGDEVKIT_DIR := external/ngdevkit
UNSIGNED_DIR := external/unsigned
SDK_BUILD := $(BUILDDIR)/ngdevkit
SDK := $(abspath $(SDK_BUILD)/install)
SDK_STAMP := $(SDK_BUILD)/.installed
ROM := $(BUILDDIR)/rom

M68KGCC := m68k-neogeo-elf-gcc
M68KOBJCOPY := m68k-neogeo-elf-objcopy
Z80SDOBJCOPY := z80-neogeo-ihx-sdobjcopy
PYTHON := python3
GNGEO := ngdevkit-gngeo
PKGCONFIG := pkg-config
CFLAGS := -std=c99 -O2 -g -Wall -Wextra -fomit-frame-pointer
LDFLAGS := -Wl,--defsym,rom_eye_catcher_mode=2
-include config.local.mk

NGCFLAGS = -I$(SDK)/m68k-neogeo-elf/include
SDK_LIB := $(SDK)/m68k-neogeo-elf/lib
NGLDFLAGS = -B$(SDK_LIB)/ -B$(SDK_LIB)/gcc/m68k-neogeo-elf/$(shell $(M68KGCC) -dumpversion)/ -L$(SDK_LIB) -specs=ngdevkit -lngdevkit
ROMTOOL = $(PYTHON) $(NGDEVKIT_DIR)/tools/romtool.py

ifeq ($(wildcard $(NGDEVKIT_DIR)/configure.ac),)
$(error Initialize dependencies with git submodule update --init --recursive)
endif
ifeq ($(wildcard $(UNSIGNED_DIR)/unsigned.mk),)
$(error Initialize dependencies with git submodule update --init --recursive)
endif
include $(UNSIGNED_DIR)/unsigned.mk

.PHONY: all sdk cart bios clean distclean gngeo gngeo-aes gngeo-mvs
all: cart bios
sdk: $(SDK_STAMP)

SDK_SOURCES := $(shell find $(NGDEVKIT_DIR) -type f ! -name .git)
$(SDK_STAMP): scripts/build-ngdevkit.sh $(SDK_SOURCES)
	+bash scripts/build-ngdevkit.sh $(NGDEVKIT_DIR) $(SDK_BUILD) "$(shell command -v $(PYTHON))"

$(UNSIGNED_OBJS): $(SDK_STAMP)

GAME_SRCS := main.c $(wildcard src/*.c)
GAME_OBJS := $(addprefix $(BUILDDIR)/,$(GAME_SRCS:.c=.o))
$(BUILDDIR)/%.o: %.c $(SDK_STAMP)
	@mkdir -p $(dir $@)
	$(M68KGCC) $(NGCFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

ELF := $(BUILDDIR)/rom.elf
$(ELF): $(GAME_OBJS) $(UNSIGNED_LIB)
	$(M68KGCC) -o $@ $^ $(LDFLAGS) $(NGLDFLAGS) -Wl,-Map,$(BUILDDIR)/rom.map

PROM := $(ROM)/$(GAMEROM)-p1.p1
SROM := $(ROM)/$(GAMEROM)-s1.s1
MROM := $(ROM)/$(GAMEROM)-m1.m1
CROM1 := $(ROM)/$(GAMEROM)-c1.c1
CROM2 := $(ROM)/$(GAMEROM)-c2.c2
VROM := $(ROM)/$(GAMEROM)-v1.v1
CART := $(ROM)/$(GAMEROM).zip
ROM_ARGS = -p $(PROM) -s $(SROM) -m $(MROM) -c $(CROM1) $(CROM2) -v $(VROM) -n $(GAMEROM) -l "$(GAMETITLE)"

$(ROM):
	mkdir -p $@
$(PROM): $(ELF) | $(ROM)
	$(M68KOBJCOPY) -O binary -S -R .text2 --gap-fill 0xff --pad-to 1048576 $< $@
	dd if=$@ of=$@ conv=notrunc,swab status=none
$(SROM): assets/font.fix | $(ROM)
	cp $< $@
	truncate -s 131072 $@
$(MROM): $(SDK_STAMP) | $(ROM)
	$(Z80SDOBJCOPY) -I ihex -O binary $(SDK)/share/ngdevkit/nullsound_driver.ihx $@ --pad-to 131072
$(CROM1) $(CROM2): | $(ROM)
	truncate -s 131072 $@
$(VROM): | $(ROM)
	truncate -s 524288 $@

cart: $(CART) $(ROM)/neogeo.xml
$(CART): $(PROM) $(SROM) $(MROM) $(CROM1) $(CROM2) $(VROM)
	$(ROMTOOL) -b cartridge -f zip $(ROM_ARGS) -o $@
$(ROM)/neogeo.xml: $(CART)
	$(ROMTOOL) -b hash -f mame $(ROM_ARGS) -o $@
bios: $(ROM)/aes.zip $(ROM)/neogeo.zip
$(ROM)/aes.zip $(ROM)/neogeo.zip: $(SDK_STAMP) | $(ROM)
	cp $(SDK)/share/ngdevkit/$(notdir $@) $@

# GnGeo is optional. Its data archive is only needed by the run targets.
GNGEO_DATA = $(shell $(PKGCONFIG) --variable=prefix ngdevkit)/share/ngdevkit-gngeo/gngeo_data.zip
$(ROM)/gngeo_data.zip: $(CART)
	$(ROMTOOL) -b hash -f gngeo $(ROM_ARGS) -x gngeo.data=$(GNGEO_DATA) -o $@
gngeo: gngeo-aes
gngeo-aes: all $(ROM)/gngeo_data.zip
	$(GNGEO) --system home --scale 3 -i $(ROM) -d $(ROM)/gngeo_data.zip $(GAMEROM)
gngeo-mvs: all $(ROM)/gngeo_data.zip
	$(GNGEO) --system arcade --scale 3 -i $(ROM) -d $(ROM)/gngeo_data.zip $(GAMEROM)

# Keep the SDK cache during ordinary game rebuilds.
clean:
	rm -rf build/unsigned build/rom build/src
	rm -f build/*.o build/*.d build/*.elf build/*.map
distclean:
	rm -rf build

-include $(GAME_OBJS:.o=.d)
