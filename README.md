# Lab 1 — RISC-V assembly: sum of a row of a 2D array

## 1. Task

Variant 5: *find the sum of the elements of the row with a given number* in a
two-dimensional array of size N x M = 4 x 4.

The array is processed in a separate function. The algorithm is implemented
in RISC-V assembly (RV32I, run in the Venus simulator) and in C
(compiled with a RISC-V compiler, with a disassembly dump of the result).

## 2. Algorithm

The array is stored in memory **row by row** (row-major), 4 bytes per `int`:

```
address of arr[i][j] = base + (i * M + j) * 4
address of row r     = base + r * M * 4 = base + r * 16     (M = 4)
```

1. Compute the address of the first element of row `r`: `base + (r << 4)`.
2. `sum = 0`, `j = 0`.
3. While `j < M`: `sum += *p; p += 4; j++`.
4. Return `sum`.

Because M = 4 is a power of two, `r * 16` is a single shift (`slli`), so the
base RV32I instruction set (which has no `mul`) is enough.

## 3. Files

| File | Purpose |
|------|---------|
| `row_sum.s` | RISC-V assembly program for Venus (`row_sum` function + `main`) |
| `row_sum.c` | C implementation of the same algorithm |
| `row_sum.dump` | full `objdump -D` of the compiled C program (includes startup code) |
| `row_sum_funcs.dump` | only the disassembly of `row_sum` and `main` (the part used in section 7) |
| `images/` | screenshots from the Venus simulator |
| `README.md` | this report |

## 4. Assembly implementation and ABI

`int row_sum(const int *a, int row)`

| Register | Role in the program |
|----------|---------------------|
| `a0` | 1st argument: address of `arr`; **return value** (the sum) |
| `a1` | 2nd argument: row number |
| `t0` | pointer to the current element |
| `t1` | column counter `j` |
| `t2` | element loaded from memory |
| `t3` | constant `M = 4` |
| `ra` | return address (set by `jal`, used by `ret`) |
| `s0` | in `main`: keeps the result while `ecall` prints it |

Only the function that processes the array receives parameters, as required.
It is called with `jal ra, row_sum` and returns with `ret` (`jalr x0, 0(ra)`).
It uses only temporary (`t*`) and argument (`a*`) registers, which a callee is
allowed to change, so nothing has to be saved on the stack.

Venus system calls used: `ecall` with the id in `a0` and the argument in `a1`
(`1` print_int, `4` print_string, `11` print_character, `10` exit).
The result is moved to `s0` before printing, because `ecall` needs `a0` for the
call id.

## 5. C implementation and build

```bash
# the toolchain from the lab (riscv-gcc-10.2.0) is on PATH
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 row_sum.c -o row_sum.elf
riscv64-unknown-elf-objdump -D row_sum.elf > row_sum.dump
```

The full dump is long because the linked program also contains the startup
code and C library routines. The part written for this lab is found under the
`<row_sum>:` and `<main>:` labels; it is also saved separately:

```bash
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -c row_sum.c -o row_sum.o
riscv64-unknown-elf-objdump -d row_sum.o > row_sum_funcs.dump
```

`N` and `M` are `#define` constants: with a constant `M` the compiler turns
`row * M` into a shift. With a variable column count it would need a
multiplication, which does not exist in `rv32i` (it would call a library
routine).

## 6. Run in Venus

1. Open https://www.kvakil.me/venus/ and paste `row_sum.s` into the editor.
2. Press *Simulator* → *Assemble & Simulate from Editor*, then *Run*.
3. Console output for row 2: `Row sum = 42`.

![Venus run, row 2: console output and registers](images/run.png)

What the screenshot shows:

* The console prints `Row sum = 42` (9 + 10 + 11 + 12).
* `s0 = 0x2a` (42) holds the result returned from `row_sum`.
* `t1 = 4`: the loop executed 4 times; `t2 = 0xc` (12) is the last element read.
* `t0 = 0x10000030` points just after the row: row 2 starts at
  `0x10000020`, and 4 elements of 4 bytes were passed (16 bytes).
* `ra = 0x10` is the return address: the `jal` is at `0x0c`, so the next
  instruction is at `0x10`.
* `a0` and `a1` contain `0xa`: these are the values of the last `ecall`
  (exit and newline), not the result.
* `la a0, arr` is a pseudo-instruction expanded into two instructions
  (`auipc` + `addi`), because one instruction cannot hold a 32-bit address.

The array in the data segment (row-major, one word = 4 bytes):

![Array in memory (data segment)](images/memory.png)

Checked results for all rows of the array
`{1,2,3,4}, {5,6,7,8}, {9,10,11,12}, {13,14,15,16}`:

| Row | Expected sum | Result |
|-----|--------------|--------|
| 0 | 10 | 10 |
| 1 | 26 | 26 |
| 2 | 42 | 42 |
| 3 | 58 | 58 |

The C version gives the same values (`result == 42` for row 2).

## 7. Comparison: my assembly vs. compiler output

Both programs solve the same task with the same ABI (array address in `a0`,
row number in `a1`, result in `a0`). The compiler output below is the
`row_sum` function from `row_sum.dump` (built without optimization, `-O0`).

| | My assembly | Compiler output (C, `-O0`) |
|---|---|---|
| Instructions in `row_sum` | 12 | 32 |
| Instructions per loop iteration | 6 | 17 |
| Stack frame | none | `addi sp,sp,-48`, saves and restores `ra` and `s0` |
| Where `sum` and `j` live | registers (`a0`, `t1`) | memory (`-20(s0)`, `-24(s0)`) |
| Arguments | stay in `a0`, `a1` | stored to the stack first (`sw a0,-36(s0)`, `sw a1,-40(s0)`), loaded again when needed |
| Element address | row address computed once before the loop, then `addi t0,t0,4` | recomputed every iteration (`slli 4`, `add`, `slli 2`, `add`) |
| Constant in the loop condition | `M = 4` kept in `t3` | `li a5,3` executed every iteration |
| Loop condition | `bge t1,t3,done` at the top of the loop, plus `j loop` at the bottom | `j < 4` compiled as `3 >= j` (`bge a5,a4`), checked at the bottom: one conditional branch per iteration |
| Return | result is already in `a0`, so `ret` | result is loaded from memory (`lw a5,-20(s0)`, `mv a0,a5`), stack is restored, then `ret` |

Why the compiler output is longer: without optimization the compiler gives
every variable a place in memory and executes every C statement literally, so
each `sum += a[row][j]` becomes load, compute, store. This makes debugging
easy but the code slower. My version keeps everything in registers, advances
a pointer by 4 each iteration and computes the row address once.

My loop has two jump instructions per iteration (`bge` and `j`), while the
compiler's loop has one (it checks the condition at the bottom); this could be
improved by moving my check to the end of the loop.

With `-O2` the compiler unrolls the whole loop (the row has only 4 elements):
`slli`, `add`, four `lw`, three `add`, `ret` — 10 instructions, no loop.

What is the same in both: the algorithm and the result (42 for row 2), the
ABI, `slli ... 4` to compute `row * 16`, `lw` to read the element, `add` to
accumulate, and `la` expanded into `auipc` + `addi`.

Other differences in the files: `row_sum.dump` also contains startup code
(`_start`, `_cstart`, `__riscv_save_*`) and C library routines, which is why it
is long, and its addresses start at `0x80000000` (the toolchain's linker
script), while Venus places code at `0x0` and data at `0x10000000`. `main` in
the C program stores the result in the variable `r`, while the assembly
`main` prints it with `ecall`.
