# ZBA (working title)
An in-progress Gameboy Advance Emulator written in Zig ⚡!

## Tests 
- [x] [`arm.gba`](https://github.com/jsmolka/gba-tests/tree/master/arm)
- [x] [`thumb.gba`](https://github.com/jsmolka/gba-tests/tree/master/thumb)
- [x] [`armwrestler-gba-fixed.gba`](https://github.com/destoer/armwrestler-gba-fixed)


## Resources
* [GBATEK](https://problemkaputt.de/gbatek.htm)
* [TONC](https://coranac.com/tonc/text/toc.htm)
* [ARM Architecture Reference Manual](https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/third-party/ddi0100e_arm_arm.pdf)
* [ARM7TDMI Data Sheet](https://www.dca.fee.unicamp.br/cursos/EA871/references/ARM/ARM7TDMIDataSheet.pdf)

## Compiling
Most recently built on Zig [v0.10.0-dev.662+e139c41fd](https://github.com/ziglang/zig/tree/e139c41fd8955f873615b2c2434d162585c0e44c)

### Dependencies
* [SDL.zig](https://github.com/MasterQ32/SDL.zig)
    * [SDL2](https://www.libsdl.org/download-2.0.php)
* [zig-clap](https://github.com/Hejsil/zig-clap)

On windows, it's easiest if you use [`vcpkg`](https://github.com/Microsoft/vcpkg) to install `sdl2:x64-windows`.

Once you've installed all the dependencies, run `zig build -Drelease-fast`. The executable is located at `zig-out/bin/`. 