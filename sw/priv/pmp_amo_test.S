// pmp_amo_test.S -- PMP must check atomic memory operations (A extension) like
// loads and stores. Runs on Gandiva SECURE (tb/tb_gandiva_priv.sv,
// ./build.sh priv). PMP set-up (U-mode, L=0):
//   region0: NAPOT 64 B @ 0x8000_0000  R only
//   region1: NAPOT 64 B @ 0x8000_0040  no access
//   region2: NAPOT whole space         R/W/X (catch-all)
// In U-mode the program runs:
//   1. amoadd.w to 0x8000_0000 (read-only)  -> store/AMO access fault (cause 7),
//      mtval = 0x8000_0000, memory unchanged
//   2. lr.w from 0x8000_0040 (no access)    -> load access fault (cause 5),
//      mtval = 0x8000_0040
//   3. amoadd.w to 0x8000_0100 (catch-all)  -> allowed (negative control):
//      returns the old value and updates memory
// then ECALLs back to M-mode (cause 8).
    .section .text.init, "ax"
    .globl _start
_start:
    la   t0, mtrap
    csrw mtvec, t0
    li   gp, 0                        // one bit per expected fault seen

    // seed the three data words from M-mode (no PMP rule is locked)
    li   a0, 0x80000000
    li   t0, 0x11111111
    sw   t0, 0(a0)                    // read-only word
    li   t0, 0x22222222
    sw   t0, 0x40(a0)                 // no-access word
    li   t0, 0x00000005
    sw   t0, 0x100(a0)                // catch-all word

    li   t0, 0x20000007               // NAPOT 64 B @ 0x8000_0000
    csrw pmpaddr0, t0
    li   t0, 0x20000017               // NAPOT 64 B @ 0x8000_0040
    csrw pmpaddr1, t0
    li   t0, 0xFFFFFFFF               // NAPOT whole space
    csrw pmpaddr2, t0
    li   t0, 0x001F1819               // cfg2 = NAPOT|XWR, cfg1 = NAPOT, cfg0 = NAPOT|R
    csrw pmpcfg0, t0

    li   t0, 0x1800
    csrc mstatus, t0                  // MPP = U
    la   t0, user_code
    csrw mepc, t0
    mret

    .align 2
user_code:
    li   a0, 0x80000000
    li   a1, 0x100
    amoadd.w a2, a1, (a0)             // EXPECT cause 7
    addi a3, a0, 0x40
    lr.w a4, (a3)                     // EXPECT cause 5
    addi a5, a0, 0x100
    li   a1, 3
    amoadd.w a6, a1, (a5)             // allowed: a6 = 5, memory = 8
    ecall

    .align 2
mtrap:
    csrr t3, mcause
    csrr t5, mtval
    li   t4, 8
    beq  t3, t4, finish
    li   t4, 7
    bne  t3, t4, 1f
    li   t4, 0x80000000               // AMO fault: address must be reported
    bne  t5, t4, bad_tval
    ori  gp, gp, 0x1
    j    skip
1:  li   t4, 5
    bne  t3, t4, bad_cause
    li   t4, 0x80000040
    bne  t5, t4, bad_tval
    ori  gp, gp, 0x2
skip:
    csrr t6, mepc
    addi t6, t6, 4
    csrw mepc, t6
    mret

finish:
    li   t6, 0x20000000               // tohost
    li   t4, 0x3
    bne  gp, t4, fail_faults
    li   a0, 0x80000000
    lw   t0, 0(a0)
    li   t1, 0x11111111
    bne  t0, t1, fail_mem             // the faulting AMO must not have written
    li   t1, 5
    bne  a6, t1, fail_ok
    lw   t0, 0x100(a0)
    li   t1, 8
    bne  t0, t1, fail_ok
    li   t0, 1
    sw   t0, 0(t6)                    // PASS
1:  j    1b
fail_faults:
    addi t0, gp, 0x100                // 0x100 + bitmask of faults seen
    sw   t0, 0(t6)
2:  j    2b
fail_mem:
    li   t0, 3
    sw   t0, 0(t6)
3:  j    3b
fail_ok:
    li   t0, 6
    sw   t0, 0(t6)
4:  j    4b
bad_cause:
    li   t6, 0x20000000
    li   t0, 4
    sw   t0, 0(t6)
5:  j    5b
bad_tval:
    li   t6, 0x20000000
    li   t0, 5
    sw   t0, 0(t6)
6:  j    6b
