# Makefile for posix version(Linux, BSD, OS X and so on)

-include ../Makefile.define
SRC := $(wildcard *.c)
OBJS := $(SRC:.c=.o)
DEPS := $(SRC:.c=.d)
uname_S := $(shell sh -c 'uname -s 2>/dev/null || echo not')

ifeq ($(uname_S), Darwin) # OS X
	TARGET=libposixpsutil.dylib
else
	TARGET=libposixpsutil.so
endif

-include ../Makefile.common
