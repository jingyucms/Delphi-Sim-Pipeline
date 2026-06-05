// hepmc2fadgen — generic HepMC3 -> DELPHI FADGEN (fort.26 LUJETS) converter.
//
// Reads a HepMC3 file (any generator) and writes the same Fortran-unformatted
// LUJETS record that `pythia8_generate.cpp`'s EventWriter produces and that
// DELSIM's SXRDLU reads (delsim36.car): per event an int record_size, an int N,
// then for each of N particles K[5] (int32), P[5] (float32), V[5] (float32),
// then a trailing record_size.
//
// Design notes (see recon in the project memory):
//  * Full LUJETS tree is preserved (status + mother/daughter links) — DELSIM
//    propagates the gen history into the DST SH-banks (b-tagging truth lives there).
//  * V[5] is written as zeros on purpose: DELSIM ignores the input production
//    vertex (regenerates it from the beam spot via SXBEAP) and the input proper
//    lifetime (uses its own particle table VTAU/UPTAU). Filling real vertices
//    would be discarded.
//  * Status is derived from the GENERIC HepMC3 status (1 final / 2 decayed /
//    4 beam) + PDG-based V0 tagging — NOT from any Pythia-specific status code,
//    so the same tool works for Sherpa/Whizard/etc.
//
// Closure target: for Pythia8 input this should reproduce EventWriter's fort.26
// (final-state set + decay tree), modulo benign intermediate status-code labels.

#include "HepMC3/GenEvent.h"
#include "HepMC3/GenParticle.h"
#include "HepMC3/GenVertex.h"
#include "HepMC3/ReaderAscii.h"
#include "HepMC3/Units.h"

#include <fstream>
#include <iostream>
#include <unordered_map>
#include <vector>
#include <set>
#include <cmath>
#include <string>
#include <algorithm>

using namespace HepMC3;

// V0 set whose Pythia decay is disabled so DELSIM decays them (status -> 4).
// Matches pythia8_generate.cpp exactly: K0_S, Lambda, Sigma-, Sigma+, Xi-, Xi0.
// (NB: Omega 3334 is intentionally NOT here — mirrors the current converter.)
static const std::set<int> kV0AbsPdg = {310, 3122, 3112, 3222, 3312, 3322};

// Mirror of EventWriter::isValidParticle, applied to a HepMC3 particle.
static bool isValidParticle(const ConstGenParticlePtr& p) {
    int abs_pdg = std::abs(p->pid());
    if (abs_pdg == 0) return false;
    if (abs_pdg >= 81 && abs_pdg <= 99) return false;   // JETSET special codes
    if (abs_pdg > 100000) return false;                 // very exotic
    if (abs_pdg >= 20000) return false;                 // modern states

    const FourVector& m = p->momentum();
    const double e = m.e();
    const double mass = p->generated_mass();
    if (e <= 0.0 || mass < 0.0) return false;
    if (!std::isfinite(m.px()) || !std::isfinite(m.py()) ||
        !std::isfinite(m.pz()) || !std::isfinite(e) || !std::isfinite(mass))
        return false;
    if (std::abs(m.px()) > 1000.0 || std::abs(m.py()) > 1000.0 ||
        std::abs(m.pz()) > 1000.0 || e > 1000.0) return false;
    return true;
}

// Generic HepMC3-status -> LUJETS K(,1). V0 PDGs that survive as final state
// become status 4 so DELSIM decays them (matches EventWriter's V0 handling).
//   HepMC3 1 (final) -> 1 ; 4 (beam) -> 21 ; everything else (decayed/doc) -> 2.
static int lujetsStatus(int hepmc_status, int pdg) {
    // Final-state -> K(,1)=1 (DELSIM tracks it); a V0 that survives to final
    // state -> K(,1)=4 (DELSIM decays it). Everything else (HepMC3 beam=4,
    // decayed=2, documentation) -> K(,1)=21 documentation/history (kept in the
    // record for the gen tree but NOT tracked).
    //
    // CRITICAL: do NOT map HepMC3's "decayed" (status 2) to LUJETS K=2 -- in
    // JETSET K(,1)=2 means "final particle, last of a colour-singlet system"
    // (a TRACKED code), so marking a decayed Z / parton as 2 makes DELSIM
    // reject the whole event (reads 0 input events). HepMC3 status numbers and
    // JETSET KS numbers are different namespaces.
    if (hepmc_status == 1) {
        if (kV0AbsPdg.count(std::abs(pdg)) > 0) return 4;
        return 1;
    }
    return 21;
}

class FadgenWriter {
public:
    explicit FadgenWriter(const std::string& filename) : events_written_(0) {
        out_.open(filename, std::ios::binary);
        if (!out_) { std::cerr << "Error opening " << filename << std::endl; std::exit(1); }
    }
    ~FadgenWriter() {
        if (out_.is_open()) {
            writeEndMarker();
            out_.close();
            std::cout << "Total events written to file: " << events_written_ << std::endl;
        }
    }

    // Returns true if the event was written (accepted), false if rejected.
    bool writeEvent(const GenEvent& event, int eventNum) {
        // Stable iteration order = HepMC3 id order (event.particles() is id-sorted).
        const std::vector<ConstGenParticlePtr> all = event.particles();

        // Collect valid particles, then move the incoming BEAM particles
        // (HepMC3 status 4) to the front: DELSIM/JETSET requires the LUJETS
        // record to START with the two incoming beams (e+ e-). The rest keep
        // HepMC3 id order, which is topological (mothers before daughters);
        // since beams have no mother, hoisting them preserves that. Then build
        // the HepMC id -> 1-based output index map over the final order.
        std::vector<ConstGenParticlePtr> valid;
        valid.reserve(all.size());
        for (const auto& p : all)
            if (isValidParticle(p)) valid.push_back(p);
        std::stable_partition(valid.begin(), valid.end(),
            [](const ConstGenParticlePtr& p) { return p->status() == 4; });
        std::unordered_map<int,int> idToOut;
        idToOut.reserve(valid.size());
        for (size_t i = 0; i < valid.size(); ++i)
            idToOut[valid[i]->id()] = static_cast<int>(i + 1);  // 1-based
        const int n = static_cast<int>(valid.size());

        if (n < 2) {
            std::cout << "Event " << eventNum << " REJECTED: only " << n
                      << " valid particles" << std::endl;
            return false;
        }
        if (n > 4000) {
            // DELSIM LUJETS arrays are dimensioned (4000,5) — refuse to overflow.
            std::cerr << "Event " << eventNum << " REJECTED: " << n
                      << " particles exceeds DELSIM's ~4000 cap" << std::endl;
            return false;
        }

        // Walk up the production chain to the first valid ancestor (its 1-based
        // output index), else 0. Mirrors EventWriter::findValidMother.
        auto findValidMother = [&](const ConstGenParticlePtr& p) -> int {
            ConstGenVertexPtr pv = p->production_vertex();
            while (pv) {
                const auto& ins = pv->particles_in();
                if (ins.empty()) break;
                const ConstGenParticlePtr& mother = ins.front();
                auto it = idToOut.find(mother->id());
                if (it != idToOut.end()) return it->second;
                pv = mother->production_vertex();
            }
            return 0;
        };

        // {first,last} 1-based output indices of valid daughters (0,0 if none).
        // Mirrors EventWriter::findValidDaughters.
        auto findValidDaughters = [&](const ConstGenParticlePtr& p) -> std::pair<int,int> {
            int first = 0, last = 0;
            ConstGenVertexPtr ev = p->end_vertex();
            if (ev) {
                for (const auto& d : ev->particles_out()) {
                    auto it = idToOut.find(d->id());
                    if (it == idToOut.end()) continue;
                    const int oi = it->second;
                    if (first == 0 || oi < first) first = oi;
                    if (oi > last) last = oi;
                }
            }
            return {first, last};
        };

        // Require >= 2 final-state (status 1 or 4) particles, like EventWriter.
        int nFinal = 0;
        for (const auto& p : valid) {
            const int k1 = lujetsStatus(p->status(), p->pid());
            if (k1 == 1 || k1 == 4) ++nFinal;
        }
        if (nFinal < 2) {
            std::cout << "Event " << eventNum << " REJECTED: only " << nFinal
                      << " final-state particles" << std::endl;
            return false;
        }

        // Write the Fortran-unformatted record.
        const int record_size = 4 + n * (5 * 4 + 5 * 4 + 5 * 4);
        out_.write(reinterpret_cast<const char*>(&record_size), 4);
        out_.write(reinterpret_cast<const char*>(&n), 4);

        for (const auto& p : valid) {
            int k[5];
            k[0] = lujetsStatus(p->status(), p->pid());
            k[1] = p->pid();
            k[2] = findValidMother(p);
            const std::pair<int,int> kd = findValidDaughters(p);
            k[3] = kd.first;
            k[4] = kd.second;
            out_.write(reinterpret_cast<const char*>(k), 5 * 4);

            const FourVector& m = p->momentum();
            float pf[5];
            pf[0] = static_cast<float>(m.px());
            pf[1] = static_cast<float>(m.py());
            pf[2] = static_cast<float>(m.pz());
            pf[3] = static_cast<float>(m.e());
            pf[4] = static_cast<float>(p->generated_mass());
            out_.write(reinterpret_cast<const char*>(pf), 5 * 4);

            // V[5] = 0: DELSIM ignores input vertex/lifetime (see header note).
            const float vf[5] = {0.f, 0.f, 0.f, 0.f, 0.f};
            out_.write(reinterpret_cast<const char*>(vf), 5 * 4);
        }

        out_.write(reinterpret_cast<const char*>(&record_size), 4);
        ++events_written_;

        std::cout << "Event " << eventNum << " ACCEPTED: " << n << " particles ("
                  << nFinal << " final)" << std::endl;
        return true;
    }

private:
    void writeEndMarker() {
        const int record_size = 4;
        const int zero = 0;
        out_.write(reinterpret_cast<const char*>(&record_size), 4);
        out_.write(reinterpret_cast<const char*>(&zero), 4);
        out_.write(reinterpret_cast<const char*>(&record_size), 4);
    }

    std::ofstream out_;
    int events_written_;
};

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <input.hepmc> [output=fort.26]\n";
        return 1;
    }
    const std::string infile = argv[1];
    const std::string outfile = (argc > 2) ? argv[2] : "fort.26";

    ReaderAscii reader(infile);
    if (reader.failed()) {
        std::cerr << "Error: cannot open HepMC3 input " << infile << std::endl;
        return 1;
    }

    FadgenWriter writer(outfile);

    int read = 0, accepted = 0;
    while (!reader.failed()) {
        GenEvent evt(Units::GEV, Units::MM);
        reader.read_event(evt);
        if (reader.failed()) break;       // clean EOF or error after last event
        evt.set_units(Units::GEV, Units::MM);
        ++read;
        if (writer.writeEvent(evt, read)) ++accepted;
    }
    reader.close();

    std::cout << "\nSummary: read " << read << " events, accepted " << accepted
              << " (" << (read - accepted) << " rejected)" << std::endl;
    return 0;
}
