// encoding.h -- reduced RISC-V encoding constants for the riscv-tests "p"
// environment on Gandiva.  The official riscv-tests env submodule
// (riscv-test-env, which carries the full generated encoding.h) was not
// available in the vendored tree, so this file defines only the constants the
// vendored rv32 test sources (and the rv64 files they include) and
// riscv_test.h use.  Values follow the RISC-V Privileged Architecture
// specification (same names and values as riscv-test-env/encoding.h).
#ifndef GANDIVA_ENCODING_H
#define GANDIVA_ENCODING_H

#define MSTATUS_SIE         0x00000002
#define MSTATUS_MIE         0x00000008
#define MSTATUS_SPIE        0x00000020
#define MSTATUS_MPIE        0x00000080
#define MSTATUS_SPP         0x00000100
#define MSTATUS_MPP         0x00001800
#define MSTATUS_FS          0x00006000
#define MSTATUS_MPRV        0x00020000
#define MSTATUS_SUM         0x00040000
#define MSTATUS_MXR         0x00080000
#define MSTATUS_TVM         0x00100000
#define MSTATUS_TW          0x00200000
#define MSTATUS_TSR         0x00400000

#define SSTATUS_SIE         0x00000002
#define SSTATUS_SPIE        0x00000020
#define SSTATUS_SPP         0x00000100
#define SSTATUS_FS          0x00006000
#define SSTATUS_SUM         0x00040000
#define SSTATUS_MXR         0x00080000
#define SSTATUS_UXL         0x0000000300000000

#define SATP32_MODE         0x80000000
#define SATP64_MODE         0xF000000000000000
#if __riscv_xlen == 64
# define SATP_MODE SATP64_MODE
#else
# define SATP_MODE SATP32_MODE
#endif
#define SATP_MODE_OFF  0
#define SATP_MODE_SV32 1
#define SATP_MODE_SV39 8

#define MNSTATUS_NMIE       0x00000008

#define MIP_SSIP            (1 << 1)
#define MIP_MSIP            (1 << 3)
#define MIP_STIP            (1 << 5)
#define MIP_MTIP            (1 << 7)
#define MIP_SEIP            (1 << 9)
#define MIP_MEIP            (1 << 11)
#define SIP_SSIP            MIP_SSIP
#define SIP_STIP            MIP_STIP

#define PRV_U 0
#define PRV_S 1
#define PRV_M 3

#define PMP_R     0x01
#define PMP_W     0x02
#define PMP_X     0x04
#define PMP_A     0x18
#define PMP_L     0x80
#define PMP_TOR   0x08
#define PMP_NA4   0x10
#define PMP_NAPOT 0x18

#define MCONTROL_TYPE(xlen)  (0xfULL << ((xlen) - 4))
#define MCONTROL_DMODE(xlen) (1ULL << ((xlen) - 5))
#define MCONTROL_M          (1 << 6)
#define MCONTROL_S          (1 << 4)
#define MCONTROL_U          (1 << 3)
#define MCONTROL_EXECUTE    (1 << 2)
#define MCONTROL_STORE      (1 << 1)
#define MCONTROL_LOAD       (1 << 0)

#define CSR_MNSTATUS 0x744

#define CAUSE_MISALIGNED_FETCH    0x0
#define CAUSE_FETCH_ACCESS        0x1
#define CAUSE_ILLEGAL_INSTRUCTION 0x2
#define CAUSE_BREAKPOINT          0x3
#define CAUSE_MISALIGNED_LOAD     0x4
#define CAUSE_LOAD_ACCESS         0x5
#define CAUSE_MISALIGNED_STORE    0x6
#define CAUSE_STORE_ACCESS        0x7
#define CAUSE_USER_ECALL          0x8
#define CAUSE_SUPERVISOR_ECALL    0x9
#define CAUSE_MACHINE_ECALL       0xb
#define CAUSE_FETCH_PAGE_FAULT    0xc
#define CAUSE_LOAD_PAGE_FAULT     0xd
#define CAUSE_STORE_PAGE_FAULT    0xf

#endif
