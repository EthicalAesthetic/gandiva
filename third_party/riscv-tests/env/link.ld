/* Gandiva adaptation of riscv-tests env/p/link.ld.  The Gandiva SoC is
   Harvard-style: code runs from IMEM at 0x0 (where the core starts after
   reset; loads may also read it), and data lives in DRAM at 0x8000_0000 (the
   only region stores can write).  run_isa.sh turns the IMEM sections and the
   DRAM sections into two separate $readmemh images (+IMEM / +DMEM). */
OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  . = 0x0;
  .text.init : { *(.text.init) }
  . = ALIGN(0x100);
  .text : { *(.text) *(.text.*) }
  .rodata : { *(.rodata) *(.rodata.*) *(.srodata*) }

  . = 0x80000000;
  .data : { *(.data) *(.data.*) *(.sdata) *(.sdata.*) }
  . = ALIGN(0x40);
  .tohost : { *(.tohost) }
  .bss : { *(.bss) *(.bss.*) *(.sbss*) *(COMMON) }
  _end = .;
}
