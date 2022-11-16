# ZBA (working title)

A Game Boy Advance Emulator written in Zig ⚡!

## Scope

I'm hardly the first to write a Game Boy Advance Emulator nor will I be the last. This project isn't going to compete with the GOATs like [mGBA](https://github.com/mgba-emu) or [NanoBoyAdvance](https://github.com/nba-emu/NanoBoyAdvance). There aren't any interesting ideas either like in [DSHBA](https://github.com/DenSinH/DSHBA).

This is a simple (read: incomplete) for-fun long-term project. I hope to get "mostly there", which to me means that I'm not missing any major hardware features and the set of possible improvements would be in memory timing or in UI/UX. With respect to that goal, here's what's outstanding:

### TODO

- [ ] Affine Sprites
- [ ] Windowing (see [this branch](https://git.musuka.dev/paoda/zba/src/branch/window))
- [ ] Audio Resampler (Having issues with SDL2's)
- [ ] Immediate Mode GUI
- [ ] Refactoring for easy-ish perf boosts

## Usage

As it currently exists, ZBA is run from the terminal. In your console of choice, type `./zba --help` to see what you can do.

I typically find myself typing `./zba -b ./bin/bios.bin ./bin/test/suite.gba` to see how badly my "cool new feature" broke everything else.

Need a BIOS? Why not try using the open-source [Cult-Of-GBA BIOS](https://github.com/Cult-of-GBA/BIOS) written by [fleroviux](https://github.com/fleroviux) and [DenSinH](https://github.com/DenSinH)?

Finally it's worth noting that ZBA uses a TOML config file it'll store in your OS's data directory. See `example.toml` to learn about the defaults and what exactly you can mess around with.

## Tests

GBA Tests | [jsmolka](https://github.com/jsmolka/)
--- | ---
`arm.gba`,  `thumb.gba` | PASS
`memory.gba`, `bios.gba` | PASS
`flash64.gba`, `flash128.gba` | PASS
`sram.gba` | PASS
`none.gba` | PASS
`hello.gba`, `shades.gba`, `stripes.gba` | PASS
`nes.gba` | PASS

GBARoms | [DenSinH](https://github.com/DenSinH/)
--- | ---
`eeprom-test`, `flash-test` | PASS
`midikey2freq` | PASS
`swi-tests-random` | FAIL

gba_tests | [destoer](https://github.com/destoer/)
--- | ---
`cond_invalid.gba` | PASS
`dma_priority.gba` | PASS
`hello_world.gba` | PASS
`if_ack.gba` | PASS
`line_timing.gba` | FAIL
`lyc_midline.gba` | FAIL
`window_midframe.gba` | FAIL

GBA Test Collection | [ladystarbreeze](https://github.com/ladystarbreeze)
--- | ---
`retAddr.gba` | PASS
`helloWorld.gba` | PASS
`helloAudio.gba` | PASS

FuzzARM | [DenSinH](https://github.com/DenSinH/)
--- | ---
`main.gba` | PASS

arm7wrestler GBA Fixed | [destoer](https://github.com/destoer)
--- | ---
`armwrestler-gba-fixed.gba` | PASS

## Resources

- [GBATEK](https://problemkaputt.de/gbatek.htm)
- [TONC](https://coranac.com/tonc/text/toc.htm)
- [ARM Architecture Reference Manual](https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/third-party/ddi0100e_arm_arm.pdf)
- [ARM7TDMI Data Sheet](https://www.dca.fee.unicamp.br/cursos/EA871/references/ARM/ARM7TDMIDataSheet.pdf)

## Compiling

Most recently built on Zig [v0.11.0-dev.144+892fb0fc8](https://github.com/ziglang/zig/tree/892fb0fc8)

### Dependencies

Dependency | Source
SDL.zig | <https://github.com/MasterQ32/SDL.zig>
zig-clap | <https://github.com/Hejsil/zig-clap>
known-folders | <https://github.com/ziglibs/known-folders>
zig-toml | <https://github.com/aeronavery/zig-toml>
zig-datetime | <https://github.com/frmdstryr/zig-datetime>
`bitfields.zig` | [https://github.com/FlorenceOS/Florence](https://github.com/FlorenceOS/Florence/blob/aaa5a9e568/lib/util/bitfields.zig)
`gl.zig` | <https://github.com/MasterQ32/zig-opengl>

Use `git submodule update --init` from the project root to pull the git submodules `SDL.zig`, `zig-clap`, `known-folders`, `zig-toml` and `zig-datetime`

Be sure to provide SDL2 using:

- Linux: Your distro's package manager
- MacOS: ¯\\\_(ツ)_/¯
- Windows: [`vcpkg`](https://github.com/Microsoft/vcpkg) (install `sdl2:x64-windows`)

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
