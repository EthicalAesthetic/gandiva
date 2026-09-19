/* Gandiva adaptation of riscv-tests env/p/link.ld for tests that write or
   execute their own code/data region (rv32ui/fence_i, rv32uc/rvc).  All
   sections are linked contiguously at 0x0 into IMEM, and run_isa.sh runs them
   with the testbench's +IMEM_RW option, which makes IMEM a unified code+data
   RAM like the FPGA SoC (fpga/gandiva_fpga.sv). */
OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  . = 0x0;
  .text.init : { *(.text.init) }
  . = ALIGN(0x100);
  .text : { *(.text) *(.text.*) }
  .rodata : { *(.rodata) *(.rodata.*) *(.srodata*) }
  . = ALIGN(0x100);
  .data : { *(.data) *(.data.*) *(.sdata) *(.sdata.*) }
  . = ALIGN(0x40);
  .tohost : { *(.tohost) }
  .bss : { *(.bss) *(.bss.*) *(.sbss*) *(COMMON) }
  _end = .;
}
