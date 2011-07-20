CFLAGS=-O2 -Wall -std=c99 -lpthread -lrt
CC=gcc ${CFLAGS}
BUILD_DIR='../bin'
BIN_NAME='cpuhogs'
SRC= loop.c cpucmd.c cpuhog.c
OBJ= $(SRC:.c=.o)

all: prepare ${BIN_NAME} clean
	@echo success making ${BIN_NAME}

prepare:
	if test ! -d $(BUILD_DIR); then mkdir $(BUILD_DIR); fi
${BIN_NAME} : ${OBJ} 
	${CC} -o $(BUILD_DIR)/$@ ${OBJ}
%.o : %.c
	${CC} -o $@ -c $<
clean:
	rm -f ${OBJ}
