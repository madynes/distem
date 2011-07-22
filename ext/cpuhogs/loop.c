
int LOOP2(int x) {
	/* CPU intensive loop */
	int i, j;
	for (i=0; i < 10; i++)
		for (j=0; j < 10; j++)
			x ^= x + (i & j);
	return x;
}
