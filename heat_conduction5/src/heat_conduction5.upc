/*
 ============================================================================
 Name        : heat_conduction5.upc
 Author      : vahichen
 Version     :
 Copyright   : Your copyright notice
 Description : UPC Heat Conduction program
 ============================================================================
*/

#include <stdio.h>
#include <math.h>
#include <upc_relaxed.h>
#include "globals.h"

#ifndef NULL
#define NULL   ((void *) 0)
#endif

#define MEM_OK(var) {                                        	 \
    if( var == NULL )                                          	 \
    {                                                        	 \
        printf("TH%02d: ERROR: %s == NULL\n", MYTHREAD, #var );	 \
        upc_global_exit(1);                                    	 \
    } }

typedef struct chunk_s {
	shared [] double *chunk;
} chunk_t;

shared chunk_t sh_grids[2][THREADS];
shared double dTmax_local[THREADS];

#define grids(num, z, y, x) sh_grids[num][((z)*N*N+(y)*N+(x))/(N*N*N/THREADS)].chunk[((z)*N*N+(y)*N+(x))%(N*N*N/THREADS)]

void initialize(shared chunk_t (*sh_grids)[THREADS]) {

	int x, y;
	for (y = 1; y < N -1; y++) {
		upc_forall(x = 1; x < N - 1; x++; &grids(0, 0, y, x)) {
			grids(0, 0, y, x) = grids(1, 0, y, x) = 1.0;
		}
	}
}

int heat_conduction(shared chunk_t (*sh_grids)[THREADS]) {

	int i, j, k;
	int x, y, z, iter = 0, finished = 0;
	int sg = 0, dg = 1;
	double T, dTmax, dT, epsilon = 0.0001;

	upc_barrier;

	do {
		dTmax = 0.0;
		for (z = 1; z < N - 1; z++) {
			for (y = 1; y < N - 1; y++) {
				upc_forall(x = 1; x < N - 1; x++; &grids(sg, z, y, x)) {
					T = (grids(sg, z+1, y, x) + grids(sg, z-1, y, x) +
							grids(sg, z, y+1, x) + grids(sg, z, y-1, x) +
							grids(sg, z, y, x+1) + grids(sg, z, y, x-1)) / 6.0;
					dT = T - grids(sg, z, y, x);
					grids(dg, z, y, x) = T;
					if (dTmax < fabs(dT)) {
						dTmax = fabs(dT);
					}
				}
			}
		}
		dTmax_local[MYTHREAD] = dTmax;
		upc_barrier;

		dTmax = dTmax_local[0];
		for (i = 1; i < THREADS; i++) {
			if (dTmax < dTmax_local[i]) {
				dTmax = dTmax_local[i];
			}
		}
		upc_barrier;

		iter++;
		if (dTmax < epsilon) {
			finished = 1;
		} else {
			dg = sg;
			sg = !sg;
		}
		upc_barrier;

	} while (!finished);

	return iter;
}

void printgrid(shared chunk_t (*sh_grids)[THREADS], int iter);

int main(int argc, char *argv[]) {

	int iter, i;

	// allocate
	for (i = 0; i < 2; i++) {
		sh_grids[i][MYTHREAD].chunk = (shared [] double *)
				upc_alloc(N * N * N / THREADS * sizeof(double));
		MEM_OK(sh_grids[i][MYTHREAD].chunk);
	}
	upc_barrier;

	initialize(sh_grids);
	upc_barrier;

	iter = heat_conduction(sh_grids);
	upc_barrier;

	if (MYTHREAD == 0) {
		printgrid(sh_grids, iter);
	}

	return 0;
}



void printgrid(shared chunk_t (*sh_grids)[THREADS], int iter) {

	int i, j, k;

	for (i = 0; i < N; i++) {
		printf("******** z = %d ********\n", i);
		for (j = 0; j < N; j++) {
			for (k = 0; k < N; k++) {
				printf("%2f ", grids(iter%2, i, j, k));
			}
			printf("\n");
		}
	}
	printf("============ iter = %d =============\n", iter);
}
