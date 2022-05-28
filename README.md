# ZBA (working title)
An in-progress Gameboy Advance Emulator written in Zig ⚡!

## Tests 
- [ ] [jsmolka GBA Test Collection](https://github.com/jsmolka/gba-tests)
    - [x] `arm.gba` and `thumb.gba`
    - [x] `flash64.gba`, `flash128.gba`, `none.gba`, and `sram.gba`
    - [x] `hello.gba`, `shades.gba`, and `stripes.gba`
    - [x] `memory.gba`
    - [x] `bios.gba`
    - [ ] `nes.gba`
- [ ] [DenSinH's GBA ROMs](https://github.com/DenSinH/GBARoms)
    - [x] `eeprom-test`
    - [x] `flash-test`
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
- [ ] [ladystarbreeze's GBA Test Collection](https://github.com/ladystarbreeze/GBA-Test-Collection)
    - [x] `retAddr.gba`
    - [x] `helloWorld.gba`
    - [ ] `helloAudio.gba`
- [x] [`armwrestler-gba-fixed.gba`](https://github.com/destoer/armwrestler-gba-fixed)
- [x] [FuzzARM](https://github.com/DenSinH/FuzzARM)

## Resources
* [GBATEK](https://problemkaputt.de/gbatek.htm)
* [TONC](https://coranac.com/tonc/text/toc.htm)
* [ARM Architecture Reference Manual](https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/third-party/ddi0100e_arm_arm.pdf)
* [ARM7TDMI Data Sheet](https://www.dca.fee.unicamp.br/cursos/EA871/references/ARM/ARM7TDMIDataSheet.pdf)

## Compiling
Most recently built on Zig [0.10.0-dev.1933+5f2d0d414](https://github.com/ziglang/zig/tree/5f2d0d414)

### Dependencies
* [SDL.zig](https://github.com/MasterQ32/SDL.zig)
    * [SDL2](https://www.libsdl.org/download-2.0.php)
* [zig-clap](https://github.com/Hejsil/zig-clap)
* [known-folders](https://github.com/ziglibs/known-folders)
* [`bitfields.zig`](https://github.com/FlorenceOS/Florence/blob/f6044db788d35d43d66c1d7e58ef1e3c79f10d6f/lib/util/bitfields.zig)

`bitfields.zig` from [FlorenceOS](https://github.com/FlorenceOS) is included under `lib/util/bitfield.zig`.

Use `git submodule update --init` from the project root to pull the git submodules `SDL.zig`, `zig-clap`, and `known-folders`

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
<kbd>A</kbd> | Left Shoulder
<kbd>S</kbd> | Right Shoulder
<kbd>Return</kbd> | Start
<kbd>RShift</kbd> | Select
Arrow Keys | D-Pad
