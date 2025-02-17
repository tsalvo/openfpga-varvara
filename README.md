# openfpga-varvara

A core for Analogue Pocket that is an early work-in-progress FPGA implementation of [Varvara / Uxn](https://100r.co/site/uxn.html) by [Hundred Rabbits](https://100r.co/site/home.html)).

### Screenshots
![Tet](/screenshots/tet.png?raw=true) ![Flappy Bird](/screenshots/flappy_bird.png?raw=true) ![Donsol](/screenshots/donsol.png?raw=true) ![Amiga](/screenshots/amiga.png?raw=true)

## Running the core on an Analogue Pocket

Unzip the latest core from the _Releases_ section, and copy + merge the `Assets`, `Cores`, and `Platforms` folders to your Analogue Pocket SD Card.

## Specs

- Display: 320x288 at 60Hz
- CPU: 44.411585 MHz
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
- keyboard
- file system
- console

ROMs larger than 65280 bytes probably won't work, because only the first 64KB is loaded into RAM, and there is no expansion memory support.

## Test ROMs

I added some test ROMs into the `dist/assets` folder. Some of these are slightly modified examples from the [Uxn Chibicc fork](https://github.com/lynn/chibicc) example code:

- `bounce.rom` - bouncing square demo
- `fill_test.rom` - draws a pattern of fills from bottom-right and then top-left
- `mandelbrot.rom` - draws a Mandelbrot, vertical line-by-line
- `cube3d.rom` - draws a spinning 3D wireframe cube

## Building the core yourself (optional)

### Building the RBF

#### Windows / Linux: 

Use Quartus Lite Edition to open the project at `src/fpga/ap_core.qpf` and build.

#### macOS:

Use a Docker Quartus image to build:

Clean (example command using a Docker Quartus Image):
```
docker run --platform linux/amd64 -t --rm -v $(pwd):/build didiermalenfant/quartus:22.1-apple-silicon quartus_sh --clean ap_core.qpf  
```

Build (example command using a Docker Quartus Image):
```
docker run --platform linux/amd64 -t --rm -v $(pwd):/build didiermalenfant/quartus:22.1-apple-silicon quartus_sh --flow compile ap_core.qpf
```
### Reversing the RBF

The resulting bitstream at `output_files/ap_core.rbf` will need to be reversed into a `bitstream.rbf_r` file, before running on a Pocket. 

See [Creating a reversed RBF](https://www.analogue.co/developer/docs/packaging-a-core#creating-a-reversed-rbf) for more details. 
