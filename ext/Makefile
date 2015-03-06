CC := gcc
LDLIBS := -shared
CCFLAGS := -MP -MMD -Wall

uname_S := $(shell sh -c 'uname -s 2>/dev/null || echo not')
SRC := common.c

ifeq ($(platform), posix)
# Makefile for posix version(Linux, BSD, OS X and so on)
SRC += posix.c

ifeq ($(uname_S), Darwin) # OS X
	TARGET=posix/libposixpsutil.dylib
else
	TARGET=posix/libposixpsutil.so
endif

else
# Makefile for Linux version
platform=linux
SRC += linux.c
TARGET=linux/libposixpsutil.so

endif

OBJS := $(SRC:.c=.o)
DEPS := $(SRC:.c=.d)

$(TARGET): $(OBJS)
	@if [ ! -d $(platform) ]; then \
		mkdir $(platform); \
	fi
	$(CC) $(OBJS) $(LDLIBS) -o $(TARGET)

%.o : %.c
	$(CC) -fPIC -O2 -c $(CCFLAGS) $< -o $@

-include $(DEPS)

clean:
	rm -rf $(OBJS) $(DEPS) linux/* posix/*

install: $(TARGET)
	rm -rf $(OBJS) $(DEPS)

.PHONY: clean install
