/* Lab 1, variant 5: sum of the elements of the row with a given number.
 * Array: N x M = 4 x 4 (N - row size, M - column size, both 4 here). */

#define N 4
#define M 4

int arr[N][M] = {
    { 1,  2,  3,  4},
    { 5,  6,  7,  8},
    { 9, 10, 11, 12},
    {13, 14, 15, 16}
};

volatile int result;               /* the value to inspect in the simulator */

/* Array processing is done in a separate function.
 * a   - pointer to the first element of the array (row-major layout)
 * row - number of the row to sum (0 .. N-1) */
int row_sum(const int a[N][M], int row)
{
    int sum = 0;
    for (int j = 0; j < M; j++)
        sum += a[row][j];
    return sum;
}

int main(void)
{
    result = row_sum(arr, 2);      /* 9 + 10 + 11 + 12 = 42 */
    return 0;
}
