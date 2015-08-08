BIN=bin
FFIGEN=ml-nlffigen
POSTGRES_INCLUDE=/usr/include/postgresql
#CFLAGS=-m32

# Building for smlnj (via ml-nlffigen), requires 32 bit libpq
#
# To install on Debian,
#
# $ dpkg --add-architecture i386
# $ apt-get update
# $ apt-get install libpq5:i386

build: smlnj
	@echo "== Standard ML Postgresql Bindings =="

smlnj:
	sml build.sml
	cd libpq && \
		$(FFIGEN) -d FFI -lh LibpqH.libh -include ../libpq-h.sml \
				 -cm libpq.h.cm -D__builtin_va_list="void*" \
				-target x86-unix \
				 ${POSTGRES_INCLUDE}/libpq-fe.h

	cd libpq && sml build.sml
	sml build.sml

test:
	sml bin/go-nj.sml
	bin/.mkexec `which sml` `pwd` pq-test
	./bin/pq-test

clean:
	rm -rf libpq/FFI/.cm
	rm -rf libpq/.cm
	rm -rf .cm

.PHONY: clean mlton smlnj
