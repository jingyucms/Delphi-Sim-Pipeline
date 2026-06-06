# KK2f Makefile for gfortran (qq final state ONLY)
FC = gfortran
FFLAGS = -fno-automatic -ffixed-form -ffixed-line-length-132 -std=legacy -fno-range-check -O2

# Directories
KK2F_DIR = KK-v4-14/KK-all/KK2f
GLIBK_DIR = KK-v4-14/KK-all/glibk
BORNV_DIR = KK-v4-14/KK-all/bornv
DIZET_DIR = KK-v4-14/KK-all/dizet
PHOTOS_DIR = KK-v4-14/KK-all/photos
JETSET_DIR = KK-v4-14/KK-all/jetset
TAUOLA_DIR = KK-v4-14/KK-all/tauola
PYTHIA_DIR = pythia6156
DELFOR_DIR = delfor

# Include directories
INCLUDES = -I$(KK2F_DIR) -I$(GLIBK_DIR) -I$(BORNV_DIR) -I$(DIZET_DIR) -I$(DELFOR_DIR) -I$(JETSET_DIR) -I$(TAUOLA_DIR)

# CERN libraries
CERN_LIBS = -L/delphi/releases/almalinux-9-x86_64/latest/cern/pro/lib64 -lmathlib -lpacklib -lkernlib -llapack -lm -lnsl -lcrypt -ldl

# DELPHI libraries
DELPHI_LIBS = -L/delphi/releases/almalinux-9-x86_64/latest/dstana/161018/lib -ldstanaxx

# JETSET library
JETSET_OBJS = $(JETSET_DIR)/jetset74.o

# KK2f source files (includes Taupair/Tauface for tau handling)
KK2F_OBJS = $(KK2F_DIR)/KarFin.o $(KK2F_DIR)/QED3.o $(KK2F_DIR)/YFSini2.o \
            $(KK2F_DIR)/KarLud.o $(KK2F_DIR)/GPS.o $(KK2F_DIR)/KinLib.o \
            $(KK2F_DIR)/PseuMar.o $(KK2F_DIR)/BVR.o $(KK2F_DIR)/ReaData.o \
            $(KK2F_DIR)/KK2f.o $(KK2F_DIR)/Taupair.o $(KK2F_DIR)/Tauface.o

# GLIBK source files
GLIBK_OBJS = $(GLIBK_DIR)/GLK.o $(GLIBK_DIR)/MathLib.o

# BORNV source files
BORNV_OBJS = $(BORNV_DIR)/BornV.o $(BORNV_DIR)/Vesk1.o $(BORNV_DIR)/BStra.o \
             $(BORNV_DIR)/IRC.o $(BORNV_DIR)/MBrA.o $(BORNV_DIR)/MBrB.o \
             $(BORNV_DIR)/VegasA.o $(BORNV_DIR)/VegasB.o $(BORNV_DIR)/VegasC.o \
             $(BORNV_DIR)/FoamA.o $(BORNV_DIR)/FoamB.o $(BORNV_DIR)/FoamC.o

# DIZET source files
DIZET_OBJS = $(DIZET_DIR)/DZface.o $(DIZET_DIR)/bcqcdl5_14.o \
             $(DIZET_DIR)/m2tcor5_11.o $(DIZET_DIR)/zf514_aux.o \
             $(DIZET_DIR)/bkqcdl5_14.o $(DIZET_DIR)/dizet6_21.o \
             $(DIZET_DIR)/BornV_StartEW.o

# PHOTOS source files
PHOTOS_OBJS = $(PHOTOS_DIR)/photos.o

# TAUOLA source files
TAUOLA_OBJS = $(TAUOLA_DIR)/tauola.o $(TAUOLA_DIR)/formf.o

# Pythia source files (minimal pytaud for qq)
PYTHIA_OBJS = $(PYTHIA_DIR)/pyt6156_tau.o $(PYTHIA_DIR)/pydecy.o $(PYTHIA_DIR)/pytaud_standalone.o

# DELFOR source files (dummy tauola for qq, real tunpy with gethad)
DELFOR_OBJS = $(DELFOR_DIR)/delkk_pyface.o $(DELFOR_DIR)/delkk_kkflags_dump.o \
              $(DELFOR_DIR)/HepEvt_py6156.o $(DELFOR_DIR)/delkk_pyflags_dump.o \
              $(DELFOR_DIR)/tunupd.o $(DELFOR_DIR)/tunpy6131be.o $(DELFOR_DIR)/delkk_tauola_dummy.o

# All objects
ALL_OBJS = $(JETSET_OBJS) $(KK2F_OBJS) $(GLIBK_OBJS) $(BORNV_OBJS) $(DIZET_OBJS) \
           $(PHOTOS_OBJS) $(TAUOLA_OBJS) $(PYTHIA_OBJS) $(DELFOR_OBJS)

# Main program
MAIN_OBJ = DelKK_qq.o

# Executable
TARGET = kk2f_qq.exe

all: $(TARGET)

$(TARGET): $(MAIN_OBJ) $(ALL_OBJS)
	$(FC) $(FFLAGS) -o $@ $(MAIN_OBJ) $(ALL_OBJS) $(CERN_LIBS) $(DELPHI_LIBS)

$(MAIN_OBJ): DelKK_prod_25-Apr-2002.f
	$(FC) $(FFLAGS) $(INCLUDES) -c $< -o $@

%.o: %.f
	$(FC) $(FFLAGS) $(INCLUDES) -c $< -o $@

clean:
	rm -f $(ALL_OBJS) $(MAIN_OBJ) $(TARGET)

.PHONY: all clean
