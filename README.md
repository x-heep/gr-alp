# GR-ALP

GR-ALP (General Repository for X-ALP) is a template repository for building your own SoC on top of [X-ALP](https://github.com/x-heep/x-alp), the application-class (CVA6, RV64) sibling of [X-HEEP](https://github.com/x-heep/x-heep). If you're not yet familiar with X-ALP, go check it out first!

It shows the recommended way to extend X-ALP: instead of forking X-ALP, create a top-level repository that **vendors X-ALP as an immutable dependency** and adds your own hardware, software, and configuration around it. This keeps your project updatable while everything you own lives outside the vendored tree. Its sibling for X-HEEP is [GR-HEEP](https://github.com/x-heep/gr-heep).

X-ALP lives in `hw/vendor/x-alp/`, pinned to an exact commit by `hw/vendor/x-alp.vendor.hjson` and managed with the [vendor tool](https://opentitan.org/book/util/doc/vendor.html) (`util/vendor.py`). You never modify the vendored code, fixes go upstream or into patches.

On top of it, GR-ALP adds:

| Directory | Purpose |
|---|---|
| `config/` | The SoC configuration: `mcu-gen-config.py` (CPU, last-level cache, address map, peripherals) and `gr-alp_pad_cfg.py` (pad ring). |
| `hw/gr-alp/` | GR-ALP's own RTL top around X-ALP (`gr_alp.sv.tpl`): X-ALP's external AXI and register interfaces are where your IPs plug in. |
| `hw/fpga_ext/` | FPGA wrapper (AUP-ZU3, and ZCU104 with the DDR4 controller behind the last-level cache); board support comes from X-ALP. |
| `gr-alp.core` | The [FuseSoC](https://fusesoc.readthedocs.io/) core (`x-heep:systems:gr-alp`) that ties everything together for targets like simulation or synthesis. |
| `sw/` | Applications (`sw/applications/`); drivers, runtime and linker scripts come from X-ALP (`sw/device`, `sw/linker`). |
| `tb/`, `test/` | Testbench (X-ALP's, with `gr_alp` as DUT) and the app compile-and-simulate test suite. |
| `.github/workflows/` | CI, including the nightly canary that keeps X-ALP updated. |

The root `Makefile` forwards any target it does not define to X-ALP's own Makefile, so all the standard X-ALP commands work from the repository root.

## Using this repository as a template

1. Fork the repository.
2. Rename it to your project: `make rename NAME=<your-name>` replaces GR-ALP in every spelling (`gr-alp`, `gr_alp`, `GR-ALP`, `GR_ALP`) in file contents and paths: modules, FuseSoC core, config, apps, CI. Then run `make mcu-gen` again.
3. Start shaping your SoC by adding your IPs in `hw/` and configuring the system in `config/mcu-gen-config.py`.

## Adding your own hardware

- Keep your IP in its own repository and vendor it the same way X-ALP is: add a `hw/vendor/<your_ip>.vendor.hjson` pinning the upstream URL and revision, run `make vendor-update MODULE_NAME=<your_ip>`, and depend on its FuseSoC core from the relevant fileset in `gr-alp.core` (`depend:` entry). This keeps your accelerator versioned and updatable independently of the SoC. For quick experiments, plain RTL under `hw/` listed in the `files_rtl_generic` fileset of `gr-alp.core` also works.
- Connect it in `hw/gr-alp/gr_alp.sv.tpl` to X-ALP's external AXI slave/master ports (the `ext_slaves` region of the address map in `config/mcu-gen-config.py`) or to its external register interface (the `Ext_peripheral` window).
- If your module needs generated code, provide it as a `*.tpl` template anywhere in the tree. `make mcu-gen` discovers and expands it automatically.
- Write your applications in `sw/applications`.

## Getting started

Set up the X-ALP environment (see its README: conda environment or `.venv`, and `RISCV_XALP` pointing to the RISC-V toolchain, without `/bin`). Then, from the repository root:

```bash
make mcu-gen              # generate the RTL and SW headers from config/
make app PROJECT=gr_alp_hello_world   # build the firmware -> sw/build/main.spm.elf
make verilator-build      # build the Verilator simulation model
make verilator-run        # run the app on the simulated HW
make test                 # compile and simulate all the apps

make vivado-fpga FPGA_BOARD=zcu104   # build an FPGA bitstream (also aup-zu3)
```

Run `make help` for the list of X-ALP targets.
