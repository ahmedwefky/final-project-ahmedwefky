# simple makefile for react_app
CC ?= $(CROSS_COMPILE)gcc

all: react_app

react_app: react_app.c
	$(CC) -O2 -Wall -o $@ $<

clean:
	rm -f react_app
