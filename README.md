# unsigned-template

Minimal C99 project for Neo Geo AES/MVS using ngdevkit and Unsigned.

## Dependencies

The two Git submodules are pinned under `external/`:

- `ngdevkit`: https://github.com/dciabrin/ngdevkit
- `unsigned`: https://github.com/dvanschepdael/unsigned

Install the ngdevkit cross-toolchain (68k GCC and Z80 SDCC), GNU Make,
Bash, Autoconf, Automake, pkg-config, Python 3, tar, zip and coreutils.
See `external/ngdevkit/README.md` for platform installation instructions.
On Windows, use an MSYS2 **UCRT64** terminal.

```sh
git clone --recurse-submodules https://github.com/dvanschepdael/unsigned-template.git
cd unsigned-template
# For an existing checkout:
git submodule update --init --recursive
make -j2
```

The first build compiles and installs the pinned ngdevkit SDK under
`build/ngdevkit/install`, using the cross-compilers available in `PATH`.
Its sources are copied into `build/ngdevkit/source` for compilation.
Unsigned is compiled from its submodule into `build/unsigned/unsigned.a`.
The game links both local libraries, with LTO enabled for Unsigned.
No global SDK installation is modified.

Outputs:

- `build/rom/unsigned-template.zip`: cartridge ROM.
- `build/rom/neogeo.xml`: MAME software definition.
- `build/rom/aes.zip`, `build/rom/neogeo.zip`: open-source nullbios.
- `build/rom.elf`, `build/rom.map`: executable and linker map for debugging.

## Run and customize

With ngdevkit's GnGeo installed, run `make gngeo-aes` or `make gngeo-mvs`.
Set `GNGEO_DATA=/path/to/gngeo_data.zip` if its data archive is elsewhere.

The template uses Unsigned's ATTRACT/TITLE/GAME/GAME_OVER runtime.
Press START to begin (insert a credit first on MVS), A to end the game,
then release and press A again to return. The default sound driver is silent.

`main()` delegates BIOS USER 1/2 to `unsigned_neo_geo_main()`, and
`main_mvs_title()` delegates USER 3 to `unsigned_neo_geo_main_mvs()`.
Unsigned initializes platform services before calling `game_initialize()` for
USER 2/3, with START requests disabled until initialization succeeds.
Put game setup in this callback and use `.start_game` for each new session.
An optional `.shutdown` callback can release game resources before returning
control to the BIOS; START requests are also disabled during shutdown.

Edit `main.c` to implement initialization and phase callbacks. Additional
`src/*.c` files are compiled automatically. Change `GAMEROM` and `GAMETITLE` in the Makefile to
rename the cartridge. `assets/font.fix` supplies the text tiles; sprite and
sample ROMs are empty placeholders. See `assets/README.md` for font attribution.

Optional local overrides go in the ignored `config.local.mk`, for example:

```make
GNGEO := /path/to/ngdevkit-gngeo
GNGEO_DATA := /path/to/gngeo_data.zip
```

`make clean` removes game outputs and preserves the SDK cache.
`make distclean` removes all build outputs. After changing the ngdevkit revision,
run `make distclean && make -j2` for a fresh SDK build.

## Legal notices and third-party credits

The template's own code and documentation, including
`scripts/build-ngdevkit.sh` and `assets/README.md`, are distributed under the
Apache License 2.0; see [LICENSE](LICENSE). Third-party dependencies and assets
retain the licenses and notices described below.

[ngdevkit](https://github.com/dciabrin/ngdevkit), developed by Damien Ciabrini
and contributors, provides the runtime, tools, nullbios and nullsound used by
this template. It is distributed under the GNU Lesser General Public License,
version 3 or later (LGPL-3.0-or-later); see its
[LGPL](external/ngdevkit/COPYING.LESSER) and [GPL](external/ngdevkit/COPYING)
texts. [Unsigned](https://github.com/dvanschepdael/unsigned) is also distributed
under LGPL-3.0-or-later; see its [license notice](external/unsigned/README.md#license),
[LGPL](external/unsigned/COPYING.LESSER) and [GPL](external/unsigned/COPYING.txt)
texts. Copyright remains with the respective authors and contributors.
These dependencies are provided without warranty, as stated in their licenses.

`assets/font.fix` contains converted Unscii glyphs created by Viznut, using
the public-domain font variants identified by ngdevkit-examples. The tileset
was generated with the ngdevkit-examples conversion tools by Damien Ciabrini
and contributors. See [asset credits and provenance](assets/README.md) for
the original notices and conversion sources.

Other development tools, libraries and optional emulators retain their own
licenses and copyright notices. Third-party names and trademarks belong to
their respective owners; their use here identifies dependencies and platform
compatibility and does not imply endorsement or affiliation. These credits
do not replace the applicable license texts or grant additional rights over
third-party components.
