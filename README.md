Fragment : Additive/Spectral/Granular/Subtractive/PM/PD/Wavetable/Physical modelling synthesizer
=====

Raw synthesizer built for the [Fragment Synthesizer](https://github.com/grz0zrg/fsynth), a [web-based and pixels-based collaborative synthesizer](https://www.fsynth.com)

This program should compile on most platforms!

Table of Contents
=================

* [<a href="https://www.fsynth.com">Fragment Synthesizer</a>](#fragment-:-additive/spectral/granular/pm-synthesizer)
   * [About FAS](#about)
      * [Pixels-based](#pixels-based)
      * [Additive synthesis](#additive-synthesis)
      * [Granular synthesis](#granular-synthesis)
      * [Spectral synthesis (planned)](#spectral-synthesis-(planned))
      * [Sampler](#sampler)
      * [Subtractive synthesis](#subtractive-synthesis)
      * [PM synthesis](#pm-synthesis)
      * [Wavetable synthesis (WIP)](#wavetable-synthesis)
      * [Physical modelling](#physical-modelling)
      * [Formant synthesis](#formant-synthesis)
      * [Phase Distorsion synthesis](#phase-distorsion-synthesis)
      * [Modal synthesis](#modal-synthesis)
      * [Input](#input)
      * [Samples map](#samples-map)
      * [Effects](#effects)
      * [Performances](#performances)
         * [Raspberry PI](#raspberry-pi)
         * [Distributed/multi-core synthesis](#distributed/multi-core-synthesis)
         * [Frames drop](#frames-drop)
      * [Limitations](#limitations)
      * [What is sent](#what-is-sent)
      * [Offline rendering (planned)](#offline-rendering-(planned))
      * [OSC](#osc)
   * [Technical Implementation](#technical-implementation)
   * [Packets description](#packets-description)
   * [Building FAS](#build)
   * [Cross-compiling under Linux for Windows](#cross-compiling-under-linux-for-windows)
   * [Makefile rules](#makefile-rules)
   * [Usage](#usage)

## About

Fragment Audio Server (FAS) is a pixels-based graphical audio synthesizer implemented as a WebSocket server with the C language.

The versatility of its sound engine allow a wide variety of synthesis methods to produce sounds:

* additive / spectral synthesis
* phase modulation (PM/FM)
* granular
* subtractive synthesis
* physical modelling (Karplus-strong, droplet)
* wavetable

There is a second type of synthesis methods which use any synthesis methods from above as input:

* formant synthesis (formant filter bank)
* modal synthesis (resonant filter bank)
* phase distorsion

There is also input channels which just play input audio so effects or second synthesis type can be applied.

All the synthesis methods can be used at the same time by using different output channels, there is no limit on the number of output channels.

FAS is focused on **real-time performances**, being **cross-platform** and **pixels-based**.

This project was built for the [Fragment Synthesizer](https://github.com/grz0zrg/fsynth) client, a [web-based graphical audio / spectral collaborative synthesizer](https://www.fsynth.com)

The most pixels-adapted synthesis methods are (in order) additive/spectral, wavetable, granular/PM/Physical modelling; re-synthesis is possible with all of them.

### Pixels-based

Unlike other synthesizers, the notes data format understood by FAS is entirely pixels-based, the notes data format can be

- **8-bit RGBA**
- **32-bit float RGBA**

The RGBA data collected is 1px wide with an user-defined height, the height is mapped to frequencies with an user-defined logarithmic frequency map.

The height can be seen as an oscillator bank which can use any type of synthesis methods listed above.

FAS collect the RGBA data over WebSocket at an user-defined rate (commonly 60 or 120 Hz), convert the RGBA data to a suitable internal data structure and produce sounds in real-time by adding sine waves + noise together (additive synthesis), subtractive synthesis, wavetable synthesis, by interpreting the data for granular synthesis (synchronous and asynchronous) or through phase modulation (PM) or physical modelling.

It can be said that FAS/Fragment is a generic image-synth (also called graphical audio synthesizer): any RGBA images can be used to produce an infinite variety of sounds by streaming bitmap data to FAS.

With a light wrapper its architecture can also be used as a generic synth right out of the box; just deal with RGBA notes.

### Specifications

Here is some architectural specifications as if it were made by a synth. manufacturer :

* polyphonic; unlimited number of voices (depend on input data height parameter)
* multitimbral; unlimited number of timbres / parts with **dedicated stereo output**
* distributed architecture; more than one instance can run on same machine / a network with independent processing of voice / part, example : [FAS relay](https://github.com/grz0zrg/fsynth/tree/master/fas_relay)
* driven by pixels data over the wire; this synth has about no limitations and is typically used with a client that implement higher order features like MIDI / OSC such as [Fragment client](https://github.com/grz0zrg/fsynth)
* multiple sound engine; additive / spectral, sample-based, subtractive, wavetable, physical modeling, frequency modulation and allow custom sound engine (WIP: through [Faust](https://faust.grame.fr/))
* high quality stereophonic audio with low latency
* fully microtonal / spectral
* unlimited effects slot per part (24 by default but adaptable); reverb, convolution, comb, delay, chorus, flanger... you can also choose to add your own effects chain since every part have dedicated stereo output
* per voice filtering for subtractive / wavetable synthesis with one multi mode filter
 * per voice effects is limited by RGBA note data (so it is quite low actually with only one multi mode filter per voice), this is one serious limitation but there is no reason this limitation can't go over with slight adjustements (dropping bitmap data / allowing layers), allowing more layers would provide unlimited effects slot per voice / unlimited modulation options but would stress data rate limit and thus increase demands on network speed / processing... maybe in the future!
* envelopes ? has it all due to stream based architecture, you can build any types (ADSR etc.) with any interpolation scheme (linear / exp etc.)
* highly optimized real-time architecture; run on low-power embedded hardware such as Raspberry
* events resolution can be defined as you wish (60 Hz but you can go above that through a parameter)
* cross-platform; run this about anywhere !

Note : "Unlimited" is actually an architectural term, in real conditions it is limited by the available processing power, frequency resolution is also limited by slice height so it may be out of tune with low resolution! (just like analog but still more precise!)

### Additive synthesis

Additive synthesis is a mean to generate sounds by adding sine waves together, it is an extremely powerful type of sound synthesis able to reproduce any waveforms in theory.

FAS allow to add some amount of white noise to the phase of each sine waves, this may result in enhancement of noisy sounds.

#### RGBA interpretation

##### Monophonic

| Components | Interpretations                |
| ---------: | :----------------------------- |
|          R | unused                         |
|          G | unused                         |
|          B | unused                         |
|          A | Amplitude value of the channel |

##### Stereophonic

| Components | Interpretations                          |
| ---------: | :--------------------------------------- |
|          R | Amplitude value of the LEFT channel      |
|          G | Amplitude value of the RIGHT channel     |
|          B | Added noise factor for the LEFT and RIGHT oscillator |
|          A | unused                                   |

### Granular synthesis

Granular synthesis is a mean to generate sounds by using small grains of sounds blended together and forming a continuous stream.

FAS grains source are audio files (.wav, .flac or any formats supported by [libsndfile](https://github.com/erikd/libsndfile)) automatically loaded into memory from the "grains" folder by default.

Both asynchronous and synchronous granular synthesis is implemented and can be used at the same time.

Granular synthesis implementation is less optimal than additive synthesis but has good performances.

The granular synthesis algorithm is also prototyped in JavaScript (one channel only) and can be tried step by step in a browser by opening the `lab/granular/algorithm.html`

All granular synthesis parameters excluding density and envelope type can be changed in real-time without issues.

**Note** : Monophonic mode granular synthesis is not implemented.

#### Window type

The grains window/envelope type is defined as a channel dependent settings, FAS allow the selection of 13 envelopes, they can be visualized in a browser by opening the `lab/envs.html` file.

#### RGBA interpretation

| Components | Interpretations                          |
| ---------: | :--------------------------------------- |
|          R | Amplitude value of the LEFT channel      |
|          G | Amplitude value of the RIGHT channel     |
|          B | Sample index bounded to [0, 1] (cyclic) and grains density when > 2 |
|          A | Grains start index bounded [0, 1] (cyclic), grains start index random [0, 1] factor when > 1, play the grain backward when negative |

### Spectral synthesis (planned)

Spectral synthesis is a mean to generate sounds by using the FFT and IFFT algorithm preserving phase information, this is one of the most powerful synthesis algorithm available, it is able to re-produce sounds with great accuracy.

### Sampler

Granular synthesis with grain start index of 0 and min/max duration of 1/1 can be used to trigger samples as-is like a regular sampler, samples are loaded from the `grains` folder.

**Note** : Monophonic mode sampler is not implemented.

### Subtractive synthesis

Subtractive synthesis start from harmonically rich waveforms which are then filtered.

The default implementation is fast and use PolyBLEP anti-aliased waveforms, an alternative, much slower which use additive synthesis is also available by commenting `POLYBLEP` in `constants.h`.

Without Soundpipe there is one high quality low-pass filter (Moog type) implemented.

With Soundpipe there is many filters type to chose from (see channel settings): moog, diode, korg 35, lpf18...

Be careful as some filters may have unstability issues with some parameters!

There is three type of band-limited waveforms : sawtooth, square, triangle

There is also a noise waveform with PolyBLEP and additional brownian / pink noise with Soundpipe.

This type of synthesis may improve gradually with more waveforms and more filters.

**Note** : Additive synthesis waveforms are constitued of a maximum of 128 partials

#### RGBA interpretation

| Components | Interpretations                          |
| ---------: | :--------------------------------------- |
|          R | Amplitude value of the LEFT channel      |
|          G | Amplitude value of the RIGHT channel     |
|          B | filter cutoff multiplier; the cutoff is set to the fundamental frequency, 1.0 = cutoff at fundamental frequency |
|          A | filter resonance [0, 1] & waveform selection on integral part (0.x, 1.x, 2.x etc) |

**Note** : Monophonic mode subtractive synthesis is not implemented.

### PM synthesis

Phase modulation (PM) is a mean to generate sounds by modulating the phase of an oscillator (carrier) from another oscillator (modulator), it is very similar to frequency modulation (FM).

PM synthesis in Fragment use a simple algorithm with one carrier and one modulator (with feedback level), the modulator amplitude and frequency can be set with B or A channel.

PM synthesis is one of the fastest method to generate sounds and is able to do re-synthesis.

#### RGBA interpretation

| Components | Interpretations                        |
| ---------: | :------------------------------------- |
|          R | Amplitude value of the LEFT channel    |
|          G | Amplitude value of the RIGHT channel   |
|          B | Fractionnal part : Modulator amplitude, Integer part : Modulator feedback level [0,1024) |
|          A | Modulator frequency                    |

**Note** : Monophonic mode PM synthesis is not implemented.

### Wavetable synthesis (WIP)

Wavetable synthesis is a sound synthesis technique that employs arbitrary periodic waveforms in the production of musical tones or notes.

Wavetable synthesis use single cycle waveforms / samples loaded from the `waves` folder.

The wavetable can be switched with the alpha channel (integral part), a linear interpolation will happen between current & next wavetable upon switch.

The wavetable cycle can be controlled through the integral part of the blue channel, which represent the whole samples map.

Wavetable synthesis is fast.

There is only one high quality low-pass filter (Moog type) implemented.

#### RGBA interpretation

| Components | Interpretations                                              |
| ---------: | :----------------------------------------------------------- |
|          R | Amplitude value of the LEFT channel                          |
|          G | Amplitude value of the RIGHT channel                         |
|          B | Filter cutoff parameter                                      |
|          A | Filter resonance [0, 1] & wavetable selection on integral part (0.x, 1.x, 2.x etc) |

**Note** : Monophonic mode Wavetable synthesis is not implemented.

### Physical modelling

Physical modelling synthesis refers to sound synthesis methods in which the waveform of the sound to be generated is computed using a mathematical model, a set of equations and algorithms to simulate a physical source of sound, usually a musical instrument.

Physical modelling in Fragment use Karplus-Strong string synthesis.

Water droplet model is also available if compiled with Soundpipe.

#### Karplus-Strong

The initial noise source is filtered by a low-pass moog filter type or a string resonator (when compiled with Soundpipe; this provide higher quality output)

This is a fast method which generate pleasant string-like sounds.

#### Droplet

Integral part of blue / alpha component correspond to the first / second resonant frequency (main resonant frequency is tuned to current vertical pixel position), fractional part of blue component correspond to damping factor and amount of energy to add back for the alpha component.

#### RGBA interpretation

| Components | Interpretations                        |
| ---------: | :------------------------------------- |
|          R | Amplitude value of the LEFT channel    |
|          G | Amplitude value of the RIGHT channel   |
|          B | Noise wavetable cutoff lp filter / fractional part : stretching factor       |
|          A | Noise wavetable res. lp filter / feedback amount with Soundpipe        |

**Note** : Monophonic mode Physical modelling synthesis is not implemented.

### Formant synthesis

Only available with Soundpipe.

Specific type of synthesis which use a canvas-mapped bank of formant filters, each activated formant filters use an user-defined channel as source. It can be used to mimic speech.

#### RGBA interpretation

| Components | Interpretations                        |
| ---------: | :------------------------------------- |
|          R | Amplitude value of the LEFT channel    |
|          G | Amplitude value of the RIGHT channel   |
|          B | integral part : source channel index / fractional part : Impulse response attack time (in seconds)       |
|          A | Impulse reponse decay time (in seconds)        |

**Note** : Monophonic mode is not implemented.

### Phase Distorsion synthesis

Only available with Soundpipe.

Specific type of synthesis which use an user-defined source channel as input and produce waveform distorsion as output.

#### RGBA interpretation

| Components | Interpretations                        |
| ---------: | :------------------------------------- |
|          R | Amplitude value of the LEFT channel    |
|          G | Amplitude value of the RIGHT channel   |
|          B | Unused       |
|          A | Amount of distorsion [-1, 1]        |

**Note** : Monophonic mode is not implemented.

### Modal synthesis

Only available with Soundpipe.

Specific type of synthesis which use a canvas-mapped bank of resonant filters, each activated resonant filters use an user-defined channel as source. It produce sounds similar to physical modelling.

#### RGBA interpretation

| Components | Interpretations                        |
| ---------: | :------------------------------------- |
|          R | Amplitude value of the LEFT channel    |
|          G | Amplitude value of the RIGHT channel   |
|          B | Unused       |
|          A | Q factor of the resonant filter (a Q factor around the frequency produce ok results)        |

**Note** : Monophonic mode is not implemented.

### Input

This just play an input channel. Typically used in conjunction with formant / modal / pd synthesis and effects.

#### RGBA interpretation

| Components | Interpretations                        |
| ---------: | :------------------------------------- |
|          R | Amplitude value of the LEFT channel    |
|          G | Amplitude value of the RIGHT channel   |
|          B | integral part : source channel index       |
|          A | Unused        |

**Note** : Monophonic mode is not implemented.

### Samples map

Each samples loaded from the `grains` or `waves` folder are processed, one of the most important process is the sample pitch mapping, this process try to gather informations or guess the sample pitch to map it correctly onto the user-defined image height, the guessing algorithm is in order :

1. from the filename, the filename should contain a specific pattern which indicate the sample pitch such as `A#4` or a frequency between "#" character such as `flute_#440#.wav`
2. with Yin pitch detection algorithm, this method can be heavily inaccurate and depend on the sample content

### Effects

This synthesizer support unlimited (user-defined maximum at compile time) number of effects chain per channels, all effects (phaser, comb, reverb, delay...) come from the Soundpipe library which is thus required for effects usage.

Convolution effect use impulses response which are audio files loaded from the `impulses` folder.

### Performances

This program is tailored for performances, it is memory intensive (about 512mb is needed without samples, about 1 Gb with few samples), most things are pre-allocated or pre-computed with near zero real-time allocations.

FAS should be compiled with Soundpipe for best performance / more high quality algorithms; for example subtractive moog filter see 3x speed improvement compared to the standalone algorithm.

A fast and reliable Gigabit connection is recommended in order to process frames data from the network correctly.

Poor network transfer rate limit the number of channels / the frequency resolution (frame height) / number of events to process per seconds, a Gigabit connection is good enough for most usage, for example with a theorical data rate limit of 125MB/s and without packets compression (`deflate` argument) it would allow a configuration of 8 stereo channels with 1000px height slices float data at 60 fps without issues and beyond that (2000px / 240fps or 16 stereo channels / 1000 / 240fps), 8-bit data could also be used to go beyond that limit through Gigabit. This can go further with packets compression at the price of processing time.

#### Raspberry PI

FAS was executed on a [Raspberry Pi](https://www.raspberrypi.org/) with a [HifiBerry](https://www.hifiberry.com/) DAC for example, ~500 additive synthesis oscillators can be played simultaneously on the Raspberry Pi with four cores and minimum Raspbian stuff enabled.

#### Distributed/multi-core synthesis

Due to the architecture of FAS, distributed sound synthesis is made possible by running multiple FAS instances on the same or different computer by distributing the pixels data correctly to each instances, on the same machine this only require a sufficient amount of memory.

This is the only way to exploit multiple cores on the same machine.

This need a relay program which will link each server instances with the client and distribute each events to instances based on a distribution algorithm.

A directly usable implementation with NodeJS of a distributed synthesis relay can be found [here](https://github.com/grz0zrg/fsynth/tree/master/fas_relay)

Note : Synthesis methods that require another channel as input may not work correctly, this require a minor 'group' update to the relay program.

This feature was successfully used with cheap small boards clusters and [NetJack](https://github.com/jackaudio/jackaudio.github.com/wiki/WalkThrough_User_NetJack2) in a setup with 10 quad-core ARM boards + i7 (48 cores) running, linked to the NetJack driver, it is important that the relay program run on a powerfull board with (most importantly) a good Gigabit Ethernet controller to reduce latency issues.

#### Frames drop

Frames drop happen if the client is too late sending its slices per frame (this is controlled by the `frames_queue_size` option parameter), different reasons can make that happen such as slow connectivity, client side issues like a slow client, etc.

When a frame is dropped, FAS hold the audio till a frame is received or the `max_drop` program option is reached, this ensure smooth audio even if the client has issues sending its frames, latency can be heard if too much frames are dropped however.

### Limitations

Only one client is supported at the moment, the server will refuse any more connection if one client is connected, you can launch multiple servers instance on different port and feed it different data if you need a multi-client audio server

### What is sent

The server send the CPU load of the stream at regular interval (adjustable) to the client (double type).

### Offline rendering (WIP)

FAS support real-time rendering of the pixels data, the pixels data is compressed on-the-fly into a single file, FAS can then do offline processing and be used again to convert the pixels data into an audio .flac file, this  ensure professional quality audio output.

### Future

The ongoing development is to improve analysis / synthesis algorithms with Soundpipe library and implement new type of synthesis like spectral (through fft, not additive) with the help of the essentia framework (a C essentia wrapper is available).

There is also minor architectural work to do, especially better handling of effects settings data.

### OSC

FAS support OSC output of pixels data if the flag "WITH_OSC" is defined at compile time, OSC data is sent on the channel "/fragment" with data type "idff" and data (in order) "osc index", "osc frequency", "osc amplitude L value", "osc amplitude R value"

With OSC you can basically do whatever you want with the pixels data, feeding SuperCollider synths for example, sending the data as an OSC bundle is WIP.

## Technical implementation

The audio callback contain its own synth. data structure, the data structure is filled from data coming from a lock-free ring buffer to ensure thread safety for the incoming notes data.

A free list data structure is used to handle data reuse, the program pre-allocate a pool of notes buffer that is reused.

There is a generic lock-free thread-safe commands queue for synth. parameters change (gain, etc.), unlike main notes data there is some call to free() in the audio callback and allocation in the network thread when changes happen, this has room for improvements but is usually ok since this data does not change once set.

The architecture is done so there is **no memory allocation** done in the audio callback and very few done in the network thread (mainly for packets construction) as long as there is no changes in synth. parameters (bank height) nor effects parameters that require new initialization (for example convolution impulse length)

Additive synthesis is wavetable-based.

Real-time resampling is done with a simple linear method, granular synthesis can also be resampled by using cubic interpolation method (uncomment the line in `constants.h`) which is slower than linear.

All synthesis algorithms (minus [PolyBLEP](http://www.martin-finke.de/blog/articles/audio-plugins-018-polyblep-oscillator/) and Soundpipe provided) are customs.

This program is checked with Valgrind and should be free of memory leaks.

## Packets description

To communicate with FAS with a custom client, there is only five type of packets to handle, the first byte of the packet is the packet identifier, below is the expected data for each packets

**Note** : synth settings packet must be sent before sending any frames, otherwise the received frames are ignored.

Synth settings, packet identifier 0 :
```c
struct _synth_settings {
    unsigned int h; // image/slice height
    unsigned int octave; // octaves count
    unsigned int data_type; // the frame data type, 0 = 8-bit, 1 = float
    double base_frequency;
};
```

Frame data, packet identifier 1 :
```c
struct _frame_data {
    unsigned int channels; // channels count
    unsigned int monophonic; // 0 = stereo, 1 = mono
    // Note : the expected data length is computed by : (4 * (_synth_settings.data_type * sizeof(float)) * _synth_settings.h) * (fas_output_channels / 2)
    // Example with one output channel (L/R) and a 8-bit image with height of 400 pixels : (4 * sizeof(unsigned char) * 400)
    void *rgba_data;
};
```

Synth gain, packet identifier 2 :
```c
struct _synth_gain {
    double gain_lr;
};
```

Synth channels settings, packet identifier 3 :

`unsigned int channels_count;` followed by

```c
struct _synth_chn_settings {
    unsigned int synthesis_method; // mapping can be found in constants.h
    // generic integer parameter
    // Granular : granular envelope type for this channel (there is 13 types of envelopes)
    // Subtractive : filter type  (require Soundpipe)
    // Physical modeling : Physical model type (require Soundpipe)
    int p0; 
    // generic floating-point parameters (only used by granular synthesis right now)
    double p1; // granular grain duration (min. bound)
    double p2; // granular grain duration (max. bound)
    double p3; // granular grain spread

    // contain effects settings
    struct _synth_fx_settings fx[FAS_MAX_FX_SLOTS];
};
```

*for every channels.*

Server actions, packet identifier 4 :

- At the moment, this just reload samples in the grains folder, this should be followed by a synth settings change to pre-compute grains tables.

## Build

Under Windows, [MSYS2](https://msys2.github.io/) with mingw32 is used and well tested.

Requirements :

 * [PortAudio](http://www.portaudio.com/download.html)
 * [liblfds](http://liblfds.org/)
 * [libwebsockets](https://libwebsockets.org/)
 * [liblo](http://liblo.sourceforge.net/) (Optional)
 * libsamplerate
 * [Soundpipe](https://github.com/PaulBatchelor/Soundpipe) (Optional)

The granular synthesis part make use of [libsndfile](https://github.com/erikd/libsndfile) and [tinydir](https://github.com/cxong/tinydir) (bundled)

Compiling requirements for Ubuntu/Raspberry Pi/Linux (default build) :

 * Get latest [PortAudio v19 package](http://www.portaudio.com/download.html)
   * sudo apt-get install libasound-dev jackd qjackctl libjack-jackd2-dev
   * uncompress, go into the directory
   * ./configure
   * make clean
   * make
   * sudo make install
   * the static library can now be found at "lib/.libs/libportaudio.a"
 * Get latest [liblfds 7.1.1 package](http://liblfds.org/)
   * uncompress, go into the directory "liblfds711"
   * go into the directory "build/gcc_gnumake"
   * make
   * "liblfds711.a" can now be found in the "bin" directory
 * Get latest [libwebsockets 2.2.x package](https://libwebsockets.org/) from github
   * sudo apt-get install cmake zlib1g-dev
   * go into the libwebsockets directory
   * mkdir build
   * cd build
   * cmake .. -DLWS_WITH_SSL=0 -DLWS_WITHOUT_CLIENT=1
   * make
   * sudo make install
   * "libwebsockets.a" can now be found in the "build/lib" directory
 * Get latest [liblo package](http://liblo.sourceforge.net/) (only needed if WITH_OSC is defined / use OSC makefile rule)
   * uncompress, go into the directory "liblo-0.29"
   * ./configure
   * make
   * copy all libraries found in "src/.libs/" to FAS root folder
   * sudo make install
* Get latest [libsamplerate](http://www.mega-nerd.com/SRC/download.html)
  * you may need to specify the build type on configure (example for NanoPi NEO2 : ./configure --build=arm-linux-gnueabihf)
  * you may need to install libfftw : `sudo apt-get install libfftw3-dev`
  * uncompress, go into the directory "libsamplerate-0.1.9"
  * ./configure
  * make
  * copy the library found in "src/.libs/libsamplerate.a" to FAS root folder
* Get latest [Soundpipe](https://github.com/PaulBatchelor/Soundpipe)
  * make
  * "libsoundpipe.a" can now be found in the Soundpipe directory

Copy include files of portaudio / soundpipe / libwebsocket into "inc" directory.

FAS now use liblfds720 which is not yet released thus you may have to use a wrapper to liblfds711 which can be found [here](https://github.com/grz0zrg/fas/issues/4#issuecomment-457007224)

Copy the \*.a into "fas" root directory then compile by using one of the rule below (recommended rule for Linux and similar is `release-static-o` **without** Soundpipe and `release-static-sp-o` **with** Soundpipe).

Recommended launch parameters with HiFiBerry DAC+ :
    ./fas --alsa_realtime_scheduling 1 --frames_queue_size 63 --sample_rate 48000 --device 2
Bit depth is fixed to 32 bits float at the moment.

**Note** : Advanced optimizations can be enabled when compiling (only -DFIXED_WAVETABLE at the moment, which will use a fixed wavetable length of 2^16 for fast phase index warping), bandwidth enhanced sines can also be disabled for lightning fast additive synthesis.

## Cross-compiling under Linux for Windows

The audio server was successfully cross-compiled under Windows (x86_64) with the Ubuntu package **mingw-w64** and the **win-cross-x86-64** makefile rule.

Most libraries will compile easily, some may take some workaround which are noted below, notably those which are using **cmake** (liblo, libwebsockets) and also libsndfile/libsamplerate.

The makefile rules get the libraries from a "cross" folder in the FAS root directory.

For those which are using cmake, a custom cmake toolchain file must be used

##### Custom cmake toolchain for x86_64

`set(CMAKE_SYSTEM_NAME Windows)`
`set(TOOLCHAIN_PREFIX x86_64-w64-mingw32)`

`set(CMAKE_C_COMPILER ${TOOLCHAIN_PREFIX}-gcc)`
`set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PREFIX}-g++)`
`set(CMAKE_RC_COMPILER ${TOOLCHAIN_PREFIX}-windres)`

`set(CMAKE_FIND_ROOT_PATH /usr/${TOOLCHAIN_PREFIX})`

`set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)`
`set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)`
`set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)`

##### PortAudio with ASIO etc.

`./configure --build=x86_64 --host=x86_64-w64-mingw32 --with-jack --with-alsa -with-winapi=asio,directx,wdmks,wmme --with-asiodir=~/crosscompile/ASIOSDK2.3`

`make clean`

`make`

##### With liblo (WITH_OSC only)

`cmake -DCMAKE_TOOLCHAIN_FILE=~/toolchain.cmake ../cmake`

##### With libwebsockets

`cmake -DLWS_WITH_SSL=0 -DCMAKE_TOOLCHAIN_FILE=~/toolchain.cmake ..`

##### For libsndfile & libsamplerate

`./configure --build=x86_64 --host=x86_64-w64-mingw32`

## Makefile rules

Debug : **make**

Debug (with libessentia) : **make debug-essentia**

Debug (with Soundpipe) : **make debug-soundpipe**

Profile (benchmark) : **make profile**

Release : **make release**

Release with OSC : **make release-osc**

Statically linked : **make release-static**

Statically linked, with OSC and advanced optimizations : **make release-static-osc-o**

Statically linked and advanced optimizations : **make release-static-o**

Statically linked, advanced optimizations, netjack without ALSA : **release-static-netjack-o**

Statically linked + Soundpipe and advanced optimizations : **make release-static-sp-o**

Statically linked with bandlimited-noise, advanced optimizations (default build) : **make release-bln-static-o**

Statically linked + Soundpipe with bandlimited-noise, advanced optimizations (default build) : **make release-bln-static-sp-o**

Statically linked, advanced optimizations and profiling: **make release-static-o-profile**

Statically linked (with libessentia) : **make release-essentia-static**

With MinGW (Statically linked) :  **make win-release-static**

With MinGW (Statically linked + advanced optimizations, default build) :  **make win-release-static-o**

With mingw-w64 package (Ubuntu) cross-compilation for Windows : **make win-cross-x86-64**

## Usage

You can tweak this program by passing parameters to its arguments, for command-line help : **fas --h**

A wxWidget user-friendly launcher is also available [here](https://github.com/grz0zrg/fas_launcher)

Usage: fas [list_of_parameters]
 * --i **print audio device infos**
 * --sample_rate 44100
 * --noise_amount 0.1 **the maximum amount of band-limited noise**
 * --frames 512 **audio buffer size**
 * --wavetable_size 8192 **no effects if built with advanced optimizations option**
 * --fps 60 **data stream rate, client monitor Hz usually, you can experiment with this but this may have strange effects**
 * --smooth_factor 8.0 **this is the samples interpolation factor between frames**
 * --ssl 0
 * --deflate 0 **data compression (add additional processing)**
 * --max_drop 60 **this allow smooth audio in the case of frames drop, allow 60 frames drop by default which equal to approximately 1 sec.**
 * --render target.fs **real-time pixels-data offline rendering, this will save pixels data to "target.fs" file**
 * --render_convert target.fs **this will convert the pixels data contained by the .fs file to a .flac file of the same name**
 * --osc_out 0 **you can enable OSC output of notes by setting this argument to 1**
 * --osc_addr 127.0.0.1 **the OSC server address**
 * --osc_port 57120 **the OSC server port**
 * --grains_folder ./grains/
 * --granular_max_density 128 **this control how dense grains can be (maximum)**
 * --waves_folder ./waves/
 * --impulses_folder ./impulses/
 * --rx_buffer_size 8192 **this is how much data is accepted in one single packet**
 * --port 3003 **the listening port**
 * --iface 127.0.0.1 **the listening address**
 * --device -1 **PortAudio audio output device index or full name (informations about audio devices are displayed when the app. start)**
 * --input_device -1 **PortAudio audio input device index or full name (informations about audio devices are displayed when the app. start)**
 * --output_channels 2 **stereo pair**
 * --input_channels 2 **stereo pair**
 * --alsa_realtime_scheduling 0 **Linux only**
 * --frames_queue_size 7 **important parameter, if you increase this too much the audio might be delayed**
 * --commands_queue_size 16 **should be a positive integer power of 2**
 * --stream_load_send_delay 2 **FAS will send the stream CPU load every two seconds**
 * --samplerate_conv_type -1 **see [this](http://www.mega-nerd.com/SRC/api_misc.html#Converters) for converter type, this has impact on samples loading time, this settings can be ignored most of the time since FAS do real-time resampling, -1 skip the resampling step**

Self-signed certificates are provided in case you compile/run it with SSL. (Note: This is useless for many reasons and HTTP should _**ALWAYS**_ be the prefered protocol for online Fragment application, this is explained in [this issue](https://github.com/grz0zrg/fas/issues/1).)

**You can stop the application by pressing any keys while it is running on Windows or by sending SIGINT (Ctrl+C etc.) under Unix systems.**

https://www.fsynth.com
