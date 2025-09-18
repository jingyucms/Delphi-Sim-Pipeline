# Simple Pythia8 Pipeline for DELPHI Simulation

This repository provides a simple pipeline to run DELPHI detector simulation with **Pythia8** on **CERN lxplus** using Condor.

---

## 🚀 Configuration

### 1. Modify the submission script
Edit the **Arguments** section in `condor_delphi.sub`:

- `$1`: **Number of events per job**  
  ⚠️ Do **not** increase — this will cause failures.  
- `$2`: **Job name** (used as random number seed)  
- `$3`: **Output copy location** (must be your **AFS** area; EOS copy currently not supported)  
- `$4`: **Pythia config file** (e.g. `config_z_tautau.txt`)  

---

## 📦 Submission

Submit jobs with:

```bash
./submit_condor.sh
```

## ⚙️ Default Settings

- **Batches:** 10  
- **Jobs per batch:** 25  
- **Events per job:** ~2,500–3,000  

---

## 📂 Output Format

- Output files are written in **`.sdst`** (Short DST) format  
- Based on **ZEBRA** and stored as **Fortran binary**  

### 🔄 Convert to ROOT
For analysis, convert `.sdst` to **ROOT** format using the converter tool:  
👉 [delphi-nanoaod](https://github.com/jingyucms/delphi-nanoaod)
