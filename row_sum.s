# Lab 1, variant 5: sum of the elements of the row with a given number.
# Array 4 x 4 (N = 4, M = 4), RV32I, runs in the Venus simulator.
#
# row_sum(a0 = address of arr, a1 = row number) -> a0 = sum of the row
# The array is stored row by row (row-major), 4 bytes per element,
# so one row occupies 4 * 4 = 16 bytes.

.data
arr:    .word 1, 2, 3, 4          # row 0  -> sum 10
        .word 5, 6, 7, 8          # row 1  -> sum 26
        .word 9, 10, 11, 12       # row 2  -> sum 42
        .word 13, 14, 15, 16      # row 3  -> sum 58
msg:    .asciiz "Row sum = "

.globl main
.text
main:
    la   a0, arr              # 1st argument: address of the array
    li   a1, 2                # 2nd argument: row number (change to test)
    jal  ra, row_sum          # call; the result comes back in a0
    mv   s0, a0               # keep the result (s0 is not changed by ecall)

    li   a0, 4                # Venus ecall 4: print_string (address in a1)
    la   a1, msg
    ecall
    li   a0, 1                # Venus ecall 1: print_int (value in a1)
    mv   a1, s0
    ecall
    li   a0, 11               # Venus ecall 11: print_character
    li   a1, 10               # '\n'
    ecall
    li   a0, 10               # Venus ecall 10: exit
    ecall

# int row_sum(const int *a /*a0*/, int row /*a1*/)
row_sum:
    slli t0, a1, 4            # t0 = row * 16  (byte offset of the row)
    add  t0, a0, t0           # t0 = address of arr[row][0]
    li   t1, 0                # t1 = j = 0
    li   t3, 4                # t3 = M = 4 (number of columns)
    li   a0, 0                # a0 = sum = 0 (also the return value)
loop:
    bge  t1, t3, done         # if (j >= M) stop
    lw   t2, 0(t0)            # t2 = arr[row][j]
    add  a0, a0, t2           # sum += t2
    addi t0, t0, 4            # next element (4 bytes)
    addi t1, t1, 1            # j++
    j    loop
done:
    ret                       # jalr x0, 0(ra): return, result is in a0
