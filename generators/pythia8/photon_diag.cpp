// photon_diag — confirm the closure finding: do final-state photons exist whose
// Pythia status falls outside EventWriter's 41-60 rescue window, so EventWriter
// (production converter) drops them from DELSIM tracking (status 2)?
//
// Runs the SAME default config + seed as closure_gen, loops the final photons,
// and reports their Pythia status distribution + the K-status EventWriter assigns.

#include "Pythia8/Pythia.h"
#include <map>
#include <iostream>
#include <string>
using namespace Pythia8;

// Exact replica of EventWriter::convertToJetsetStatus for a photon (pdg 22).
static int kStatusForPhoton(int s) {
    if (s > 0) {
        if (s == 23)            return 2;   // hard-process photon (not lepton)
        if (s >= 41 && s <= 60) return 1;   // shower photons rescued
        if (s >= 81 && s <= 99) return 1;
        if (s >= 21 && s <= 80) return 2;   // catch-all -> DROPPED
        if (s >= 11 && s <= 20) return 11;
        return 21;
    }
    return 21;
}

int main(int argc, char** argv) {
    int nev = (argc > 1) ? std::atoi(argv[1]) : 30;

    Pythia pythia;
    pythia.readString("Random:setSeed = on");
    pythia.readString("Random:seed = 12345");
    pythia.readString("Beams:idA = 11");
    pythia.readString("Beams:idB = -11");
    pythia.readString("Beams:eCM = 91.187");
    pythia.readString("WeakSingleBoson:ffbar2gmZ = on");
    pythia.readString("23:onMode = off");
    pythia.readString("23:onIfAny = 1 2 3 4 5");
    pythia.readString("PartonLevel:ISR = on");
    pythia.readString("PartonLevel:FSR = on");
    pythia.readString("HadronLevel:all = on");
    for (int id : {310, 3122, -3122, 3322, -3322, 3112, -3112, 3222, -3222, 3312, -3312})
        pythia.readString(std::to_string(id) + ":mayDecay = false");
    if (!pythia.init()) { std::cerr << "init failed\n"; return 1; }

    std::map<int,int> dropStatus;  // Pythia status of dropped final photons
    std::map<int,int> kCount;      // EventWriter K assigned to final photons
    int nFinalPhoton = 0, nDropped = 0;

    for (int ie = 0; ie < nev; ++ie) {
        if (!pythia.next()) continue;
        for (int i = 0; i < pythia.event.size(); ++i) {
            const Particle& p = pythia.event[i];
            if (p.id() != 22 || !p.isFinal()) continue;   // final-state photons
            ++nFinalPhoton;
            const int k = kStatusForPhoton(p.status());
            ++kCount[k];
            if (k != 1 && k != 4) { ++nDropped; ++dropStatus[p.status()]; }
        }
    }

    std::cout << "events=" << nev << "  final photons=" << nFinalPhoton
              << "  DROPPED by EventWriter (K not 1/4)=" << nDropped << "\n";
    std::cout << "EventWriter K-status of final photons:\n";
    for (auto& kv : kCount) std::cout << "  K=" << kv.first << ": " << kv.second << "\n";
    std::cout << "Pythia status of the DROPPED final photons:\n";
    for (auto& kv : dropStatus) std::cout << "  status " << kv.first << ": " << kv.second << "\n";
    return 0;
}
