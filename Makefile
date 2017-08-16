#!/usr/make
#
# Makefile for rlemon
#

# The toplevel directory of the source tree.  This is the directory
# that contains this "Makefile".
#
TOP = .

# The directory where parser is created.
#
GEN = $(TOP)

# C Compiler and options for use in building executables that
# will run on the platform that is doing the build.
#
BCC = gcc -O2

# Filename extensions
#
BEXE =

# This is the default Makefile target.  The objects listed here
# are what get build when you type just "make" with no arguments.
#
all: rlemon$(EXE) simple

# Rules to build the LEMON compiler generator
#
rlemon$(BEXE): $(TOP)/third_party/lemon/lemon.c
	$(BCC) -o $@ $<

# Rules to build simple parser - the outputs of rlemon.
#
simple: rlemon$(BEXE) $(TOP)/examples/simple.y $(TOP)/third_party/lemon/lempar.rs
	./rlemon$(BEXE) -T$(TOP)/third_party/lemon/lempar.rs $(TOP)/examples/simple.y

clean:
	-rm -f rlemon$(BEXE)
	-rm -f $(GEN)/examples/simple.h
	-rm -f $(TOP)/examples/simple.out