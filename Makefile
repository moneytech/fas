compiler = gcc
source = main.c
libs = liblfds710.a -lportaudio -lwebsockets -lrt -lm -lasound -ljack -pthread
static_libs = liblfds710.a libportaudio.a libwebsockets.a -lz -lrt -lm -lasound -ljack -pthread -lssl -lcrypto
win_static_libs = liblfds710.a libwebsockets_static.a libportaudio.a -lm -lz -lssl -lcrypto -lws2_32 -lgdi32
compat_options = -U__STRICT_ANSI__
output = fas
standard_options = -std=c11 -pedantic -D_POSIX_SOURCE
win_static_options = -static -static-libgcc
adv_optimization_options = -DFIXED_WAVETABLE
debug_options = -g -DDEBUG
release_options = -O2

all:
	$(compiler) $(source) ${debug_options} ${standard_options} $(libs) -o $(output)

release:
	$(compiler) $(source) ${release_options} ${standard_options} $(libs) -o $(output)

release-static:
	$(compiler) $(source) ${release_options} ${standard_options} $(static_libs) -o $(output)

release-static-o:
	$(compiler) $(source) ${release_options} ${adv_optimization_options} ${standard_options} $(static_libs) -o $(output)

win-release-static:
	$(compiler) $(source) ${release_options} ${standard_options} ${win_static_options} ${compat_options} $(win_static_libs) -o $(output)

win-release-static-o:
	$(compiler) $(source) ${release_options} ${standard_options} ${win_static_options} ${adv_optimization_options} ${compat_options} $(win_static_libs) -o $(output)

32:
	$(compiler) -m32 $(source) ${release_options} ${standard_options} $(libs) -o $(output)

64:
	$(compiler) -m64 $(source) ${release_options} ${standard_options} $(libs) -o $(output)

run: all
	./fas

run-release: release-static
	./fas
