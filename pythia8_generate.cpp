#include "Pythia8/Pythia.h"
#include <fstream>
#include <iostream>
#include <iomanip>
#include <cmath>
#include <cstdlib>
#include <ctime>
#include <unistd.h>

using namespace Pythia8;

class EventWriter {
private:
    std::ofstream outfile;
    int events_written;

    // This is temperary, might not be correct. 
    int convertToJetsetStatus(int pythia8_status) {
        if (pythia8_status > 0) {
            if ((pythia8_status >= 81 && pythia8_status <= 99)) return 1;
            
            if (pythia8_status >= 21 && pythia8_status <= 80) return 2;
            
            if (pythia8_status >= 11 && pythia8_status <= 20) return 11;
        } else {
            if (pythia8_status <= -11) return 21;
        }
        return 21;  // Default fallback
    }
    
    bool isValidParticle(const Particle& p) {
        // Check PDG code validity
        int abs_pdg = abs(p.id());
        if (abs_pdg == 0) return false;
        if (abs_pdg >= 81 && abs_pdg <= 99) return false;  // JETSET special codes
        if (abs_pdg > 100000) return false;                // Very exotic particles

	if (abs_pdg >= 20000) return false;  // Modern states
        
        // Check kinematics
        if (p.e() <= 0.0 || p.m() < 0.0) return false;
        if (!std::isfinite(p.px()) || !std::isfinite(p.py()) || 
            !std::isfinite(p.pz()) || !std::isfinite(p.e()) || 
            !std::isfinite(p.m())) return false;
        
        // Check reasonable momentum range (reject extreme values)
        if (std::abs(p.px()) > 1000.0 || std::abs(p.py()) > 1000.0 || 
            std::abs(p.pz()) > 1000.0 || p.e() > 1000.0) return false;
        
        return true;
    }
    
    bool hasMinimumFinalState(const Event& event) {
        int nFinal = 0;
        
        for (int i = 1; i < event.size(); ++i) {
            const Particle& p = event[i];
            if (p.isFinal() && isValidParticle(p)) {
                nFinal++;
            }
        }
        
        return nFinal >= 2;  // Require at least 2 final state particles
    }
    
public:
    EventWriter(const std::string& filename) : events_written(0) {
        outfile.open(filename, std::ios::binary);
        if (!outfile) {
            std::cerr << "Error opening " << filename << std::endl;
            exit(1);
        }
    }
    
    ~EventWriter() {
        if (outfile.is_open()) {
            writeEndMarker();
            outfile.close();
            std::cout << "Total events written to file: " << events_written << std::endl;
        }
    }
    
    bool writeEvent(const Event& event, int eventNum) {
        // Pre-validate event has minimum particles
        if (!hasMinimumFinalState(event)) {
            std::cout << "Event " << eventNum << " REJECTED: Too few final state particles" << std::endl;
            return false;
        }
        
        std::vector<int> validParticles;
        
        // Collect valid particles
        for (int i = 1; i < event.size(); ++i) {
            const Particle& p = event[i];
            
            if (p.status() == 0) continue;  // Skip empty entries
            if (!isValidParticle(p)) continue;
            
            validParticles.push_back(i);
        }
        
        int n = validParticles.size();
        
        // Ensure we have enough particles for DELSIM
        if (n < 2) {
            std::cout << "Event " << eventNum << " REJECTED: Only " << n << " valid particles" << std::endl;
            return false;
        }
        
        // Count different particle types for validation
        int nFinal = 0, nIntermediate = 0, nBeam = 0;
        for (int idx : validParticles) {
            int status = convertToJetsetStatus(event[idx].status());
            if (status == 1) nFinal++;
            else if (status == 2 || status == 11) nIntermediate++;
            else if (status == 21) nBeam++;
        }
        
        // Ensure we have final state particles (DELSIM needs these)
        if (nFinal < 2) {
            std::cout << "Event " << eventNum << " REJECTED: Only " << nFinal << " final state particles" << std::endl;
            return false;
        }
        
        std::cout << "Event " << eventNum << " ACCEPTED: " << n << " particles ("
                 << nFinal << " final, " << nIntermediate << " intermediate, " 
                 << nBeam << " beam)" << std::endl;
        
        // Write the event
        int record_size = 4 + n * (5*4 + 5*4 + 5*4);
        
        outfile.write(reinterpret_cast<const char*>(&record_size), 4);
        outfile.write(reinterpret_cast<const char*>(&n), 4);
        
        for (int idx : validParticles) {
            const Particle& p = event[idx];
            
            // K array
            int k[5];
            k[0] = convertToJetsetStatus(p.status());
            k[1] = p.id();
            k[2] = 0;  // Simplified mother-daughter relationships
            k[3] = 0;
            k[4] = 0;
            
            outfile.write(reinterpret_cast<const char*>(k), 5*4);
            
            // P array as float32
            float p_array[5];
            p_array[0] = static_cast<float>(p.px());
            p_array[1] = static_cast<float>(p.py());
            p_array[2] = static_cast<float>(p.pz());
            p_array[3] = static_cast<float>(p.e());
            p_array[4] = static_cast<float>(p.m());
            
            outfile.write(reinterpret_cast<const char*>(p_array), 5*4);
            
            // V array as float32
            float v_array[5];
            v_array[0] = 0.0f;  // Simplified vertex (set to origin)
            v_array[1] = 0.0f;
            v_array[2] = 0.0f;
            v_array[3] = 0.0f;
            v_array[4] = 0.0f;
            
            outfile.write(reinterpret_cast<const char*>(v_array), 5*4);
        }
        
        outfile.write(reinterpret_cast<const char*>(&record_size), 4);
        events_written++;
        
        return true;
    }
    
private:
    void writeEndMarker() {
        int record_size = 4;
        int n = 0;
        outfile.write(reinterpret_cast<const char*>(&record_size), 4);
        outfile.write(reinterpret_cast<const char*>(&n), 4);
        outfile.write(reinterpret_cast<const char*>(&record_size), 4);
    }
};

int main(int argc, char* argv[]) {
    // Parse command line arguments
    int target_events = 20;  // Default value
    std::string config_file = "";  // Default: no config file
    
    // Parse arguments: [events] [config_file]
    if (argc > 1) {
        target_events = std::atoi(argv[1]);
        if (target_events <= 0) {
            std::cerr << "Error: Number of events must be positive" << std::endl;
            std::cerr << "Usage: " << argv[0] << " [number_of_events] [config_file]" << std::endl;
            return 1;
        }
    }
    
    if (argc > 2) {
        config_file = argv[2];
    }
    
    // Generate unique random seed for each run (constrained to Pythia8 limits)
    unsigned long raw_seed = static_cast<unsigned long>(std::time(nullptr)) + static_cast<unsigned long>(getpid());
    unsigned long seed = raw_seed % 900000000;  // Keep within Pythia8's seed range
    
    Pythia pythia;
    
    std::cout << "PYTHIA 8 with Enhanced Event Validation" << std::endl;
    std::cout << "=======================================" << std::endl;
    std::cout << "Random seed: " << seed << std::endl;
    std::cout << "Target events: " << target_events << std::endl;
    if (!config_file.empty()) {
        std::cout << "Config file: " << config_file << std::endl;
    }
    
    // Set random seed
    pythia.readString("Random:setSeed = on");
    pythia.readString("Random:seed = " + std::to_string(seed));
    
    // Load configuration file if provided
    if (!config_file.empty()) {
        std::ifstream config(config_file);
        if (!config) {
            std::cerr << "Error: Cannot open config file " << config_file << std::endl;
            return 1;
        }
        
        std::string line;
        int line_num = 0;
        std::cout << "Loading configuration from " << config_file << ":" << std::endl;
        
        while (std::getline(config, line)) {
            line_num++;
            
            // Skip empty lines and comments
            if (line.empty() || line[0] == '#' || line[0] == '!') continue;
            
            // Trim whitespace
            size_t start = line.find_first_not_of(" \t");
            size_t end = line.find_last_not_of(" \t");
            if (start == std::string::npos) continue;
            line = line.substr(start, end - start + 1);
            
            std::cout << "  " << line << std::endl;
            
            if (!pythia.readString(line)) {
                std::cerr << "Warning: Config file line " << line_num 
                         << " not understood: " << line << std::endl;
            }
        }
        config.close();
    } else {
        // Default PYTHIA 8 configuration (when no config file provided)
        std::cout << "Using default configuration:" << std::endl;
        
        pythia.readString("Beams:idA = 11");
        pythia.readString("Beams:idB = -11");
        pythia.readString("Beams:eCM = 91.187");
        
        pythia.readString("WeakSingleBoson:ffbar2gmZ = on");
        pythia.readString("23:onMode = off");
        pythia.readString("23:onIfAny = 1 2 3 4 5");  // Hadronic decays only
        
        pythia.readString("PartonLevel:ISR = on");
        pythia.readString("PartonLevel:FSR = on");
        pythia.readString("HadronLevel:all = on");
        
        std::cout << "  e+e- -> Z -> hadrons at 91.187 GeV" << std::endl;
        std::cout << "  ISR/FSR enabled, hadronic decays only" << std::endl;
    }
    
    if (!pythia.init()) {
        std::cerr << "PYTHIA initialization failed!" << std::endl;
        return -1;
    }
    
    EventWriter writer("fort.26");
    
    int events_generated = 0;  // Count how many PYTHIA generated
    int events_accepted = 0;   // Count how many we accepted
    int max_attempts = target_events * 3;  // Maximum attempts
    
    std::cout << "Attempting to generate " << target_events << " validated events..." << std::endl;
    
    for (int attempt = 0; attempt < max_attempts && events_accepted < target_events; ++attempt) {
        if (!pythia.next()) {
            std::cout << "PYTHIA generation failed on attempt " << (attempt + 1) << std::endl;
            continue;
        }
        
        events_generated++;
        
        if (writer.writeEvent(pythia.event, events_generated)) {
            events_accepted++;
        }
        
        // Show progress
        if (events_accepted % 10 == 0 && events_accepted > 0) {
            std::cout << "Progress: " << events_accepted << "/" << target_events 
                     << " events accepted (from " << events_generated << " generated)" << std::endl;
        }
    }
    
    std::cout << std::endl;
    std::cout << "Final summary:" << std::endl;
    std::cout << "  PYTHIA events generated: " << events_generated << std::endl;
    std::cout << "  Events accepted for DELSIM: " << events_accepted << std::endl;
    if (events_generated > 0) {
        std::cout << "  Rejection rate: " << std::fixed << std::setprecision(1) 
                  << (100.0 * (events_generated - events_accepted) / events_generated) << "%" << std::endl;
    }
    
    return 0;
}
