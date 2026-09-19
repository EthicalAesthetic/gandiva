// upriv_test.S -- User mode may only access User-level CSRs (address bits
// [9:8] == 00) and may not execute MRET. Runs on Gandiva SECURE
// (tb/tb_gandiva_priv.sv, ./build.sh priv). PMP region0 gives U full RWX so
// only the privilege checks under test can fault. In U-mode the program runs:
//   1. csrr  mstatus        (0x300, Machine)    -> illegal instruction
//   2. csrr  sscratch       (0x140, Supervisor) -> illegal instruction
//   3. csrw  stvec          (0x105, Supervisor) -> illegal instruction
//   4. csrr  0x240          (Hypervisor range)  -> illegal instruction
//   5. mret                                     -> illegal instruction
//   6. csrr  uscratch       (0x040, User)       -> allowed (negative control)
// then ECALLs back to M-mode (cause 8). tohost=1 only if exactly the five
// privileged accesses trapped with cause 2 and mtval = the instruction, and the
// user-level access did not trap and read back its value.
    .section .text.init, "ax"
    .globl _start
_start:
    la   t0, mtrap
    csrw mtvec, t0
    li   gp, 0                        // count of illegal-instruction traps

    // region0: NAPOT over the whole space, U may R/W/X everything
    li   t0, 0xFFFFFFFF
    csrw pmpaddr0, t0
    li   t0, 0x1F                     // NAPOT | X | W | R, L=0
    csrw pmpcfg0, t0

    // drop to U-mode at user_code: mstatus.MPP = 00, mepc = user_code
    li   t0, 0x1800
    csrc mstatus, t0
    la   t0, user_code
    csrw mepc, t0
    mret

    .align 2
user_code:
    csrr t1, mstatus                  // EXPECT illegal
    csrr t1, 0x140                    // sscratch: EXPECT illegal
    li   t2, 0x100
    csrw 0x105, t2                    // stvec: EXPECT illegal
    csrr t1, 0x240                    // EXPECT illegal
    mret                              // EXPECT illegal
    li   s1, 0x0000CAFE
    csrw 0x040, s1                    // uscratch: user-level, must NOT trap
    csrr s2, 0x040
    ecall                             // back to M-mode

    .align 2
mtrap:
    csrr t3, mcause
    li   t4, 8                        // ECALL from U: finish in M-mode
    beq  t3, t4, finish
    li   t4, 2                        // illegal instruction
    bne  t3, t4, bad_cause
    csrr t5, mtval                    // must be the faulting 32-bit instruction
    csrr t6, mepc
    lw   t4, 0(t6)
    bne  t4, t5, bad_tval
    addi gp, gp, 1
    addi t6, t6, 4
    csrw mepc, t6
    mret                              // MPP=U, so this returns to user_code

finish:
    li   t6, 0x20000000               // tohost
    li   t4, 5
    bne  gp, t4, fail_count
    bne  s2, s1, fail_ucsr
    li   t0, 1
    sw   t0, 0(t6)                    // PASS
1:  j    1b
fail_count:
    addi t0, gp, 0x100                // 0x100 + number of illegal traps seen
    sw   t0, 0(t6)
2:  j    2b
fail_ucsr:
    li   t0, 3
    sw   t0, 0(t6)
3:  j    3b
bad_cause:
    li   t6, 0x20000000
    li   t0, 4
    sw   t0, 0(t6)
4:  j    4b
bad_tval:
    li   t6, 0x20000000
    li   t0, 5
    sw   t0, 0(t6)
5:  j    5b
