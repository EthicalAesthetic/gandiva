// ============================================================================
// tb_gandiva.sv — Self-checking testbench for gandiva_soc.
//
//   vvp sim/tb_gandiva +IMEM=programs/build/smoke.hex
//   vvp sim/tb_gandiva +IMEM=... +TRACE=1   (emit retire trace for co-sim)
//   +DMEM=<file>  optional: preload DRAM (0x8000_0000) as well (run_isa.sh)
//   +MAXCYC=<n>   optional: timeout in cycles (default 1,000,000,000)
//   +IMEM_RW      optional: data stores to the IMEM range (0x0..) also write
//                 IMEM, i.e. one unified code+data RAM as in the FPGA SoC
//                 (fpga/gandiva_fpga.sv). gandiva_soc itself drops such stores.
//                 Used by run_isa.sh for tests that write their own code region.
//
// Exit protocol: a store to tohost (0x2000_0000) ends the run.
//   tohost == 1  -> PASS
//   tohost != 1  -> FAIL
// ============================================================================
`timescale 1ns/1ps

module tb_gandiva;
  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic rst;

  logic [31:0] tohost;
  logic        tohost_we;
  logic        retire_valid;
  logic [31:0] retire_pc, retire_instr, retire_rd_val;
  logic        retire_rd_we;
  logic [4:0]  retire_rd;

  gandiva_soc dut (
    .clk(clk), .rst(rst),
    .tck(1'b0), .tms(1'b0), .tdi(1'b0), .tdo(),
    .tohost(tohost), .tohost_we(tohost_we),
    .retire_valid(retire_valid), .retire_pc(retire_pc),
    .retire_instr(retire_instr), .retire_rd_we(retire_rd_we),
    .retire_rd(retire_rd), .retire_rd_val(retire_rd_val)
  );

  string imem_file, dmem_file;
  integer trace_en;
  longint maxcyc = 64'd1000000000;   // 1B cycles (supports 1000+ CoreMark iterations)
  integer i;

  initial begin
    if (!$value$plusargs("IMEM=%s", imem_file)) begin
      $display("FATAL: no +IMEM=<file> given");
      $finish;
    end
    trace_en = 0;
    if ($value$plusargs("TRACE=%d", trace_en)) ;

    // clear memories
    for (i = 0; i < 16384; i = i + 1) begin
      dut.imem[i] = 32'h0000_0013;   // NOP fill
      dut.dram[i] = 32'h0;
    end

    $display("[TB] Loading IMEM from: %s", imem_file);
    $readmemh(imem_file, dut.imem);
    if ($value$plusargs("DMEM=%s", dmem_file)) begin
      $display("[TB] Loading DRAM from: %s", dmem_file);
      $readmemh(dmem_file, dut.dram);
    end
    if ($value$plusargs("MAXCYC=%d", maxcyc)) ;

    if ($test$plusargs("VCD")) begin
      $dumpfile("tb_gandiva.vcd");
      $dumpvars(0, tb_gandiva);
    end

    rst = 1'b1;
    repeat (4) @(posedge clk);
    rst = 1'b0;
    $display("[TB] Reset released");
  end

  // optional unified-memory model: mirror IMEM-range stores into IMEM
  integer imem_rw = 0;
  initial if ($test$plusargs("IMEM_RW")) imem_rw = 1;
  always @(posedge clk) begin
    if (imem_rw && !rst && dut.dmem_we && dut.in_imem) begin
      if (dut.dmem_be[0]) dut.imem[dut.imem_didx][7:0]   <= dut.dmem_wdata[7:0];
      if (dut.dmem_be[1]) dut.imem[dut.imem_didx][15:8]  <= dut.dmem_wdata[15:8];
      if (dut.dmem_be[2]) dut.imem[dut.imem_didx][23:16] <= dut.dmem_wdata[23:16];
      if (dut.dmem_be[3]) dut.imem[dut.imem_didx][31:24] <= dut.dmem_wdata[31:24];
    end
  end

  // retire trace for co-simulation
  always @(posedge clk) begin
    if (!rst && trace_en && retire_valid) begin
      $display("RETIRE pc=%08x instr=%08x rdwe=%0d rd=%0d rdval=%08x",
               retire_pc, retire_instr, retire_rd_we, retire_rd, retire_rd_val);
    end
  end

  // exit on tohost
  integer cycle = 0;
  always @(posedge clk) begin
    if (!rst) cycle <= cycle + 1;
    if (tohost_we) begin
      $display("[TB] tohost write: 0x%08x at cycle %0d", tohost, cycle);
      if (tohost == 32'd1) $display("[TB] PASS");
      else                 $display("[TB] FAIL (code %0d)", tohost);
      $finish;
    end
    if (cycle > maxcyc) begin
      $display("[TB] TIMEOUT — no tohost write");
      $finish;
    end
  end
endmodule
