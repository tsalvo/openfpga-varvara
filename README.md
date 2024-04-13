# openfpga-varvara

A core for Analogue Pocket that integrates the VHDL output of [varvara-fpga](https://github.com/tsalvo/varvara-fpga) (which is still an early work-in-progress [PipelineC](https://github.com/JulianKemmerer/PipelineC) FPGA implementation of [Varvara / Uxn](https://100r.co/site/uxn.html) by [Hundred Rabbits](https://100r.co/site/home.html)).

### Screenshots
![Tet](/screenshots/tet.png?raw=true) ![Flappy Bird](/screenshots/flappy_bird.png?raw=true) ![Donsol](/screenshots/donsol.png?raw=true) ![Amiga](/screenshots/amiga.png?raw=true)

## Running the core on an Analogue Pocket

Unzip the latest core from the _Releases_ section, and copy + merge the `Assets`, `Cores`, and `Platforms` folders to your Analogue Pocket SD Card.

## Specs

- Display: 256x256 at 60Hz
- CPU: 19.87776 MHz
- Main RAM: 64 KB
- Stack RAM: 2x 256 bytes
- Device RAM: 256 bytes

## Known issue on Analogue OS 2.0 (Fixed in 2.1)

If you see a black screen after loading a ROM, the ROM is likely actually still running. Sometimes you need to open _Core Settings_ -> _Display Mode_, and re-select a display mode, to see video output. This was a bug on Analogue's end. Upgrading to AnalogueOS 2.1 or above fixes this issue.

## Known issue on Analogue OS <= 2.1 (Fixed in 2.2)

ROMs may need to be padded with additional empty bytes (0x00) to be an even multiple of 4 bytes. Updating to Analogue OS 2.2 fixes this issue.

## Limitations and other Known Issues

Many Varvara device features aren't implemented:
- audio
- mouse
- keyboard
- file system
- console

Some Varvara devices are only partially implemented:
- datetime uses a hard-coded date
- system doesn't implement the expansion port

ROMs must be 65280 bytes or less.

## Test ROMs

I added some test ROMs into the `dist/assets` folder. Some of these are slightly modified examples from the [Uxn Chibicc fork](https://github.com/lynn/chibicc) example code:

- `bounce_256_256.rom` - bouncing square demo
- `fill_test_256_256.rom` - draws a pattern of fills from bottom-right and then top-left
- `mandelbrot_256_256.rom` - draws a Mandelbrot, vertical line-by-line
- `cube3d.rom` - draws a spinning 3D wireframe cube

## Building the core yourself

- Compile the `varvara-fpga` submodule with PipelineC:
```
pipelinec varvara-fpga/uxn.c
```
- Drag the resulting `pipelinec_output_uxn.c_1` folder from varvara-fpga project into the `scr/fpga/core/` folder
- In `vhdl_files.txt`, replace space ` ` character with newline `\n`
- In `vhdl_files.txt`, replace paths in docker container `/workdir/` with path in project: `/core`
- In `vhdl_files.txt`, add `set_global_assignment -name VHDL_FILE` prefix to all VHDL files from PipelineC
- Copy VHDL Files list into QSF file
- In PipelineC VHDL files, comment out any imports of `ieee.float_pkg.all;` with `--`

Clean (example command using a Docker Quartus Image):
```
docker run --platform linux/amd64 -t --rm -v $(pwd):/build didiermalenfant/quartus:22.1-apple-silicon quartus_sh --clean ap_core.qpf  
```

Build (example command using a Docker Quartus Image):
```
docker run --platform linux/amd64 -t --rm -v $(pwd):/build didiermalenfant/quartus:22.1-apple-silicon quartus_sh --flow compile ap_core.qpf
```

# Core Template
This is a template repository for a core which contains all of the core definition JSON files and FPGA starter code.

## Legal
Analogue’s Development program was created to further video game hardware preservation with FPGA technology. Analogue Developers have access to Analogue Pocket I/O’s so Developers can utilize cartridge adapters or interface with other pieces of original or bespoke hardware to support legacy media. Analogue does not support or endorse the unauthorized use or distribution of material protected by copyright or other intellectual property rights.
