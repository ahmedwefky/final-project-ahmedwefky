# simple makefile for react_app
CC ?= $(CROSS_COMPILE)gcc
CFLAGS ?= -O2 -Wall
LIBS ?= -lpaho-mqtt3c

all: react_app

react_app: react_app.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

clean:
	rm -f react_app
