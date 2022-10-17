# ZBA (working title)
A Game Boy Advance Emulator written in Zig ⚡!

## Scope
I'm hardly the first to write a Game Boy Advance Emulator nor will I be the last. This project isn't going to compete with the GOATs like 
[mGBA](https://github.com/mgba-emu) or [NanoBoyAdvance](https://github.com/nba-emu/NanoBoyAdvance). There aren't any interesting
ideas either like in [DSHBA](https://github.com/DenSinH/DSHBA). 

This is a simple (read: incomplete) for-fun long-term project. I hope to get "mostly there", which to me means that I'm not missing any major hardware
features and the set of possible improvements would be in memory timing or in UI/UX. With respect to that goal, here's what's outstanding: 

### TODO 
- [ ] Affine Sprites
- [ ] Windowing (see [this branch](https://git.musuka.dev/paoda/zba/src/branch/window))
- [ ] Shaders (see [this branch](https://git.musuka.dev/paoda/zba/src/branch/opengl))
- [ ] Audio Resampler (Having issues with SDL2's)
- [ ] Immediate Mode GUI
- [ ] Refactoring for easy-ish perf boosts

## Tests 
- [x] [jsmolka's GBA Test Collection](https://github.com/jsmolka/gba-tests)
    - [x] `arm.gba` and `thumb.gba`
    - [x] `flash64.gba`, `flash128.gba`, `none.gba`, and `sram.gba`
    - [x] `hello.gba`, `shades.gba`, and `stripes.gba`
    - [x] `memory.gba`
    - [x] `bios.gba`
    - [x] `nes.gba`
- [ ] [DenSinH's GBA ROMs](https://github.com/DenSinH/GBARoms)
    - [x] `eeprom-test` and `flash-test`
    - [x] `midikey2freq`
    - [ ] `swi-tests-random`
- [ ] [destoer's GBA Tests](https://github.com/destoer/gba_tests)
    - [x] `cond_invalid.gba`
    - [x] `dma_priority.gba`
    - [x] `hello_world.gba`
    - [x] `if_ack.gba`
    - [ ] `line_timing.gba`
    - [ ] `lyc_midline.gba`
    - [ ] `window_midframe.gba`
- [x] [ladystarbreeze's GBA Test Collection](https://github.com/ladystarbreeze/GBA-Test-Collection)
    - [x] `retAddr.gba`
    - [x] `helloWorld.gba`
    - [x] `helloAudio.gba`
- [x] [`armwrestler-gba-fixed.gba`](https://github.com/destoer/armwrestler-gba-fixed)
- [x] [FuzzARM](https://github.com/DenSinH/FuzzARM)

## Resources
* [GBATEK](https://problemkaputt.de/gbatek.htm)
* [TONC](https://coranac.com/tonc/text/toc.htm)
* [ARM Architecture Reference Manual](https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/third-party/ddi0100e_arm_arm.pdf)
* [ARM7TDMI Data Sheet](https://www.dca.fee.unicamp.br/cursos/EA871/references/ARM/ARM7TDMIDataSheet.pdf)

## Compiling
Most recently built on Zig [0.10.0-dev.4324+c23b3e6fd](https://github.com/ziglang/zig/tree/c23b3e6fd)

### Dependencies
* [SDL.zig](https://github.com/MasterQ32/SDL.zig)
    * [SDL2](https://www.libsdl.org/download-2.0.php)
* [zig-clap](https://github.com/Hejsil/zig-clap)
* [known-folders](https://github.com/ziglibs/known-folders)
* [zig-toml](https://github.com/aeronavery/zig-toml)
* [zig-datetime](https://github.com/frmdstryr/zig-datetime)
* [`bitfields.zig`](https://github.com/FlorenceOS/Florence/blob/aaa5a9e568/lib/util/bitfields.zig)

`bitfields.zig` from [FlorenceOS](https://github.com/FlorenceOS) is included under `lib/util/bitfield.zig`.

Use `git submodule update --init` from the project root to pull the git submodules `SDL.zig`, `zig-clap`, `known-folders`, `zig-toml` and `zig-datetime`

Be sure to provide SDL2 using: 
* Linux: Your distro's package manager
* MacOS: ¯\\\_(ツ)_/¯
* Windows: [`vcpkg`](https://github.com/Microsoft/vcpkg) (install `sdl2:x64-windows`)

`SDL.zig` will provide a helpful compile error if the zig compiler is unable to find SDL2. 

Once you've got all the dependencies, execute `zig build -Drelease-fast`. The executable is located at `zig-out/bin/`. 

## Controls
Key | Button
--- | ---
<kbd>X</kbd> | A
<kbd>Z</kbd> | B
<kbd>A</kbd> | L
<kbd>S</kbd> | R
<kbd>Return</kbd> | Start
<kbd>RShift</kbd> | Select
Arrow Keys | D-Pad
