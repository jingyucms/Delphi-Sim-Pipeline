CXX = g++
CXXFLAGS = -std=c++11 -O2 -fPIC

# Try to find PYTHIA 8 installation
ifeq ($(shell command -v pythia8-config 2>/dev/null),)
    # No pythia8-config, try common locations
    PYTHIA8_DIR = /usr/local/pythia8
    ifeq ($(wildcard $(PYTHIA8_DIR)/include/Pythia8/Pythia.h),)
        PYTHIA8_DIR = /opt/pythia8
    endif
    ifeq ($(wildcard $(PYTHIA8_DIR)/include/Pythia8/Pythia.h),)
        PYTHIA8_DIR = /usr/include
    endif
    
    INCLUDES = -I$(PYTHIA8_DIR)/include
    LIBS = -L$(PYTHIA8_DIR)/lib -lpythia8 -ldl
else
    # Use pythia8-config
    INCLUDES = $(shell pythia8-config --cflags)
    LIBS = $(shell pythia8-config --ldflags) -lpythia8
endif

# Target
pythia8_generate: pythia8_generate.cpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -o $@ $< $(LIBS)

clean:
	rm -f pythia8_generate fort.26 *.fadgen

.PHONY: clean
