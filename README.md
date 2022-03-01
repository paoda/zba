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
Most recently built on Zig [v0.10.0-dev.1037+331cc810d](https://github.com/ziglang/zig/tree/331cc810d)

### Dependencies
* [SDL.zig](https://github.com/MasterQ32/SDL.zig)
    * [SDL2](https://www.libsdl.org/download-2.0.php)
* [zig-clap](https://github.com/Hejsil/zig-clap)
* [`bitfields.zig`](https://github.com/FlorenceOS/Florence/blob/f6044db788d35d43d66c1d7e58ef1e3c79f10d6f/lib/util/bitfields.zig)

`bitfields.zig` from [FlorenceOS](https://github.com/FlorenceOS) is included under `lib/util/bitfield.zig`.

`SDL.zig` and `zig-clap` are git submodules you can init using `git submodule update --init` from your terminal. 

On Linux, be sure to have SDL2 installed using whatever package manager your distro uses. 

On Windows, it's easiest if you use [`vcpkg`](https://github.com/Microsoft/vcpkg) to install `sdl2:x64-windows`. If not, 
`SDL2.zig` will provide a helpful compile error which should help you get what you need.

On macOS? ¯\\\_(ツ)_/¯ I hope it isn't too hard to compile though. 

Once you've got all the dependencies, run `zig build -Drelease-fast`. The executable is located at `zig-out/bin/`. 

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
