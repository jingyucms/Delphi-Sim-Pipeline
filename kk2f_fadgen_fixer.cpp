#include <fstream>
#include <iostream>
#include <cmath>
#include <vector>
#include <set>

struct Particle {
    int k[5];
    float p[5];
    float v[5];
};

bool isV0Particle(int pdg) {
    int abs_pdg = std::abs(pdg);
    return (abs_pdg == 310 ||    // K0_S
            abs_pdg == 3122 ||   // Lambda
            abs_pdg == 3112 ||   // Sigma-
            abs_pdg == 3222 ||   // Sigma+
            abs_pdg == 3312 ||   // Xi-
            abs_pdg == 3322);    // Xi0
}

bool isValidParticle(const Particle& p) {
    int abs_pdg = std::abs(p.k[1]);  // Fixed: p.k[1] is the PDG code
    
    if (p.k[1] == 0) return false;
    if (abs_pdg >= 81 && abs_pdg <= 99) return false;
    if (abs_pdg >= 20000) return false;
    if (abs_pdg > 100000) return false;
    
    if (p.p[3] <= 0.0) return false;
    if (p.p[4] < 0.0) return false;
    
    for (int i = 0; i < 5; i++) {
        if (!std::isfinite(p.p[i])) return false;
    }
    
    if (std::abs(p.p[0]) > 1000.0 || std::abs(p.p[1]) > 1000.0 || 
        std::abs(p.p[2]) > 1000.0 || p.p[3] > 1000.0) return false;
    
    float p2 = p.p[0]*p.p[0] + p.p[1]*p.p[1] + p.p[2]*p.p[2];
    float e2 = p.p[3]*p.p[3];
    if (e2 < p2 - 0.1) return false;
    
    return true;
}

int main(int argc, char* argv[]) {
    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " <input.fadgen> <output.fadgen>" << std::endl;
        return 1;
    }
    
    std::ifstream infile(argv[1], std::ios::binary);
    std::ofstream outfile(argv[2], std::ios::binary);
    
    if (!infile || !outfile) {
        std::cerr << "Error opening files" << std::endl;
        return 1;
    }
    
    int events_processed = 0;
    int total_v0_converted = 0;
    
    while (true) {
        int rec_size_in;
        infile.read(reinterpret_cast<char*>(&rec_size_in), 4);
        if (infile.eof()) break;
        
        int n;
        infile.read(reinterpret_cast<char*>(&n), 4);
        
        if (n == 0) {
            outfile.write(reinterpret_cast<const char*>(&rec_size_in), 4);
            outfile.write(reinterpret_cast<const char*>(&n), 4);
            outfile.write(reinterpret_cast<const char*>(&rec_size_in), 4);
            break;
        }
        
        std::vector<Particle> particles(n);
        for (int i = 0; i < n; i++) {
            infile.read(reinterpret_cast<char*>(particles[i].k), 20);
            infile.read(reinterpret_cast<char*>(particles[i].p), 20);
            infile.read(reinterpret_cast<char*>(particles[i].v), 20);
        }
        
        int rec_size_trail;
        infile.read(reinterpret_cast<char*>(&rec_size_trail), 4);
        
        // PASS 1: Find V0 particles and mark their daughters to skip
        std::set<int> v0_daughters_to_skip;
        
        for (int i = 0; i < n; i++) {
            int status = particles[i].k[0];
            int pdg = particles[i].k[1];
            
            // Find V0 with status=11 (or status=1)
            if ((status == 11 || status == 1) && isV0Particle(pdg)) {
                // Skip all status=1 particles in a window after this V0
                for (int j = i + 1; j < std::min(i + 15, n); j++) {
                    if (particles[j].k[0] >= 11) break;
                    if (particles[j].k[0] == 1) {
                        v0_daughters_to_skip.insert(j);
                    }
                }
            }
        }
        
        // PASS 2: Build output particle list
        std::vector<Particle> valid_particles;
        int nFinal = 0, nV0 = 0;
        
        for (int i = 0; i < n; i++) {
            if (v0_daughters_to_skip.count(i)) continue;
            if (!isValidParticle(particles[i])) continue;
            
            int status = particles[i].k[0];
            
            // Only keep status 1, 2, 4, 21, 11 (11 will be filtered later if not V0)
            if (status != 1 && status != 2 && status != 4 && status != 21 && status != 11) {
                continue;
            }
            
            // Convert V0 particles (status=1 or status=11) to status=4
            if ((status == 1 || status == 11) && isV0Particle(particles[i].k[1])) {
                particles[i].k[0] = 4;
                nV0++;
                total_v0_converted++;
            }
            
            // Filter out remaining status=11 (non-V0)
            if (particles[i].k[0] == 11) continue;
            
            // Zero out mother/daughter indices
            particles[i].k[2] = 0;
            particles[i].k[3] = 0;
            particles[i].k[4] = 0;
            
            valid_particles.push_back(particles[i]);
            
            if (particles[i].k[0] == 1 || particles[i].k[0] == 4) {
                nFinal++;
            }
        }
        
        if (nFinal < 2) {
            std::cout << "Event " << (events_processed + 1) << " REJECTED: Only " 
                      << nFinal << " final state particles" << std::endl;
            events_processed++;
            continue;
        }
        
        int n_out = valid_particles.size();
        
        std::cout << "Event " << (events_processed + 1) << ": " << n << " → " 
                  << n_out << " particles (" << nFinal << " final";
        if (nV0 > 0) std::cout << ", " << nV0 << " V0";
        std::cout << ")" << std::endl;
        
        int rec_size_out = 4 + n_out * 60;
        outfile.write(reinterpret_cast<const char*>(&rec_size_out), 4);
        outfile.write(reinterpret_cast<const char*>(&n_out), 4);
        
        for (const auto& p : valid_particles) {
            outfile.write(reinterpret_cast<const char*>(p.k), 20);
            outfile.write(reinterpret_cast<const char*>(p.p), 20);
            outfile.write(reinterpret_cast<const char*>(p.v), 20);
        }
        
        outfile.write(reinterpret_cast<const char*>(&rec_size_out), 4);
        
        events_processed++;
    }
    
    std::cout << "\nProcessed " << events_processed << " events" << std::endl;
    std::cout << "V0 particles converted to status=4: " << total_v0_converted << std::endl;
    
    return 0;
}
