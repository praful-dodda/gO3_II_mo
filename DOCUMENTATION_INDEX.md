# TOAR-II BME Documentation Index

**Last Updated:** January 17, 2026
**Repository:** `/home/user/gO3_II_mo`
**Total Files:** 89 MATLAB files + documentation

---

## 📚 Documentation Files Overview

This repository contains comprehensive documentation covering all aspects of the TOAR-II BME Ozone Data Fusion framework. Use this index to quickly locate the information you need.

---

## 🎯 Quick Start Guide

**For new users or new Claude Code sessions:**

1. **Start here:** [`README.md`](#1-readmemd-main-documentation) - Main project documentation
2. **For continuing sessions:** [`SESSION_CONTEXT_CBV_IMPLEMENTATION.md`](#2-session_context_cbv_implementationmd) - Latest session context
3. **To find a specific file:** [`FILE_CATALOG.md`](#3-file_catalogmd-complete-file-inventory) - Complete file catalog (89 files)

---

## 📖 Documentation Files

### 1. README.md (Main Documentation)
**Location:** `/home/user/gO3_II_mo/README.md`
**Size:** 476 lines
**Purpose:** Comprehensive project overview and getting started guide

**Contents:**
- Project overview and key features
- Installation and setup instructions
- Quick start examples
- BME method codes explained (8-digit format)
- Global offset scenarios (0-7)
- Area codes (0-10 regions)
- Data formats (STG, STUG, STV)
- Diagnostics and troubleshooting
- HPC validation workflows
- Validation metrics
- Output file formats
- Performance optimization tips

**Use When:**
- Starting work on the project
- Understanding the overall framework
- Looking up BME method codes
- Configuring estimation parameters
- Troubleshooting common issues

---

### 2. SESSION_CONTEXT_CBV_IMPLEMENTATION.md
**Location:** `/home/user/gO3_II_mo/SESSION_CONTEXT_CBV_IMPLEMENTATION.md`
**Size:** 904 lines
**Purpose:** Complete context from latest development session (Jan 17, 2026)

**Contents:**
- **Checker-Board Validation (CBV) Implementation:**
  - New files created: `evaluateFold_CBV_monthly.m`, `runCBV_toar.m`, `plotCBVresults.m`
  - Modified files: `getCheckerBoard.m`, `computeMetrics.m`
  - Full code examples and implementation details
- **Previous work summary:**
  - BME coding system (Dec 2025)
  - neighbours_stg crash fix (Dec 2025)
  - Multi-dataset kriging (Nov 2025)
- **Key technical concepts** (BME, STG/STUG, global offset, covariance)
- **Implementation patterns** (monthly processing, STUG format usage)
- **Parameter settings** and typical values
- **Git information** and commit history
- **Quick reference commands**

**Use When:**
- Continuing work from previous session
- Understanding recent CBV implementation
- Looking up code patterns
- Reviewing previous fixes and enhancements
- Starting a new Claude Code session (feed this file first!)

---

### 3. FILE_CATALOG.md (Complete File Inventory)
**Location:** `/home/user/gO3_II_mo/FILE_CATALOG.md`
**Size:** ~89 file descriptions
**Purpose:** Comprehensive catalog of ALL 89 MATLAB files

**Contents:**
- **Organized by functional category:**
  1. Data Loading & Processing (12 files)
  2. Global Offset Computation (4 files)
  3. Covariance Modeling (4 files)
  4. Knowledge Base Creation (4 files)
  5. BME Estimation & Kriging (13 files)
  6. Validation Methods (10 files)
  7. Soft Data Management (7 files)
  8. Visualization & Plotting (11 files)
  9. Diagnostic Tools (12 files)
  10. Utility & Helper Functions (5 files)
  11. Examples & Tests (7 files)

- **For each file:**
  - Purpose and description
  - Function signature
  - Key inputs and outputs
  - Usage examples
  - Cross-references

**Use When:**
- Looking for a specific function
- Understanding file purpose and usage
- Finding related functions
- Exploring available functionality
- Planning code modifications

---

### 4. README_diagnostic_visualization.md
**Location:** `/home/user/gO3_II_mo/README_diagnostic_visualization.md`
**Size:** 341 lines
**Purpose:** Guide to BME diagnostic visualization tools

**Contents:**
- Quick start with `visualizeBMEdiagnostic.m`
- Display modes (obs, grid, both)
- Metrics (mean, variance, std)
- Model spatial grid overlay
- Diagnosing vertical lines in BME maps
- Common causes and solutions
- Diagnostic workflow examples
- Interactive features
- Output file locations

**Use When:**
- Debugging BME estimation artifacts
- Investigating vertical lines in std maps
- Understanding BME uncertainty patterns
- Comparing grid vs. observations
- Troubleshooting covariance issues

---

### 5. README_krigingME_stug_multi.md
**Location:** `/home/user/gO3_II_mo/README_krigingME_stug_multi.md`
**Size:** 308 lines
**Purpose:** Documentation for multi-dataset kriging function

**Contents:**
- Overview of multi-dataset support
- Function usage and syntax
- Examples:
  - Single dataset (backward compatible)
  - Multiple datasets (cell array)
  - Hard data only
- How it works (neighbor gathering and trimming)
- Soft data structure format
- Performance considerations
- Integration with TOAR framework
- Testing and validation
- Limitations and future work

**Use When:**
- Using multiple CTM models simultaneously
- Understanding multi-dataset kriging
- Optimizing soft data usage
- Troubleshooting multi-model estimation

---

### 6. ANALYSIS_neighbours_stg_crash.md
**Location:** `/home/user/gO3_II_mo/ANALYSIS_neighbours_stg_crash.md`
**Size:** 465 lines
**Purpose:** In-depth analysis of neighbours_stg.m crash and fix

**Contents:**
- Executive summary of crash cause
- Algorithm flow explanation (4 steps)
- Three crash scenarios:
  1. No spatial neighbors (dmax(1) too small)
  2. Space-time constraint too restrictive (dmax(3) too large)
  3. No temporal neighbors (dmax(2) too small)
- Root cause analysis
- Proper solution with code examples
- Test cases
- Recommended fix strategies (Conservative, Relaxed, Warning)

**Use When:**
- Understanding neighbours_stg.m implementation
- Debugging dmax-related crashes
- Configuring dmax parameters
- Understanding edge case handling

---

### 7. 2softdata/README.md
**Location:** `/home/user/gO3_II_mo/2softdata/README.md`
**Purpose:** Soft data integration guide for RAMP-corrected CTM models

**Use When:**
- Integrating CTM model outputs
- Working with RAMP-corrected data
- Setting up soft data structures

---

### 8. hpc_validation/README.md
**Location:** `/home/user/gO3_II_mo/hpc_validation/README.md`
**Purpose:** HPC validation system documentation

**Use When:**
- Running validation on HPC clusters
- Submitting parallel validation jobs
- Aggregating validation results

---

## 🗂️ Documentation by Topic

### Getting Started
1. [`README.md`](#1-readmemd-main-documentation) - Start here
2. Quick start examples (in README.md)
3. Installation and setup (in README.md)

### Understanding the Code
1. [`FILE_CATALOG.md`](#3-file_catalogmd-complete-file-inventory) - All 89 files documented
2. [`SESSION_CONTEXT_CBV_IMPLEMENTATION.md`](#2-session_context_cbv_implementationmd) - Recent implementations
3. Cross-reference diagrams (in FILE_CATALOG.md)

### BME Methods
1. BME method codes - README.md section
2. Extended BME codes - SESSION_CONTEXT section
3. `generateBMEcode.m`, `parseBMEcode.m` - FILE_CATALOG entries

### Data Formats
1. STG, STUG, STV formats - README.md section
2. `reformat_stg_to_stug.m` - FILE_CATALOG entry
3. Soft data structures - README_krigingME_stug_multi.md

### Validation Methods
1. LOOCV - README.md section, `validateTOAR_monthly.m` in FILE_CATALOG
2. **CBV (Checker-Board Validation)** - SESSION_CONTEXT_CBV_IMPLEMENTATION.md
3. HPC validation - hpc_validation/README.md

### Troubleshooting
1. Diagnostic tools - README_diagnostic_visualization.md
2. neighbours_stg crashes - ANALYSIS_neighbours_stg_crash.md
3. Common issues - README.md troubleshooting section
4. Vertical lines in BME maps - README_diagnostic_visualization.md

### Soft Data / CTM Models
1. Soft data integration - 2softdata/README.md
2. Multi-dataset kriging - README_krigingME_stug_multi.md
3. Soft data functions - FILE_CATALOG.md section 7

### Visualization
1. Plotting functions - FILE_CATALOG.md section 8
2. Diagnostic visualization - README_diagnostic_visualization.md
3. Example scripts - FILE_CATALOG.md section 11

---

## 🔍 How to Find Information

### "I want to understand what file X does"
→ Check [`FILE_CATALOG.md`](#3-file_catalogmd-complete-file-inventory)

### "I'm starting a new Claude Code session"
→ Read [`SESSION_CONTEXT_CBV_IMPLEMENTATION.md`](#2-session_context_cbv_implementationmd) first

### "I need to run a validation"
→ Check validation section in [`README.md`](#1-readmemd-main-documentation) or SESSION_CONTEXT for CBV

### "I'm seeing vertical lines in BME std maps"
→ Read [`README_diagnostic_visualization.md`](#4-readme_diagnostic_visualizationmd)

### "My neighbours_stg function is crashing"
→ Read [`ANALYSIS_neighbours_stg_crash.md`](#6-analysis_neighbours_stg_crashmd)

### "I want to use multiple CTM models"
→ Read [`README_krigingME_stug_multi.md`](#5-readme_krigingme_stug_multimd)

### "What BME method code should I use?"
→ Check BME method codes section in [`README.md`](#1-readmemd-main-documentation)

### "What's the latest implementation work?"
→ Read recent updates section in [`SESSION_CONTEXT_CBV_IMPLEMENTATION.md`](#2-session_context_cbv_implementationmd)

---

## 📊 Documentation Coverage Map

```
TOAR-II BME Framework Documentation
│
├── DOCUMENTATION_INDEX.md (this file)
│   └── Central navigation hub
│
├── README.md
│   ├── Project overview
│   ├── Installation
│   ├── Quick start
│   ├── BME methods & codes
│   ├── Configuration
│   └── Troubleshooting
│
├── SESSION_CONTEXT_CBV_IMPLEMENTATION.md
│   ├── Latest session work (Jan 2026)
│   ├── CBV implementation details
│   ├── Previous work summary
│   ├── Code patterns
│   └── Quick reference
│
├── FILE_CATALOG.md
│   ├── All 89 MATLAB files
│   ├── Organized by category
│   ├── Function signatures
│   ├── Usage examples
│   └── Cross-references
│
├── README_diagnostic_visualization.md
│   ├── visualizeBMEdiagnostic.m guide
│   ├── Artifact diagnosis
│   └── Troubleshooting workflows
│
├── README_krigingME_stug_multi.md
│   ├── Multi-dataset kriging
│   ├── Usage examples
│   └── Performance tips
│
├── ANALYSIS_neighbours_stg_crash.md
│   ├── Crash analysis
│   ├── Root cause
│   └── Fix implementation
│
├── 2softdata/README.md
│   └── Soft data integration
│
└── hpc_validation/README.md
    └── HPC validation system
```

---

## 🎨 File Categories Quick Reference

| Category | File Count | Documentation |
|----------|------------|---------------|
| Data Loading & Processing | 12 | FILE_CATALOG.md |
| Global Offset Computation | 4 | FILE_CATALOG.md + README.md |
| Covariance Modeling | 4 | FILE_CATALOG.md + README.md |
| Knowledge Base Creation | 4 | FILE_CATALOG.md + README.md |
| BME Estimation & Kriging | 13 | FILE_CATALOG.md + README_krigingME_stug_multi.md |
| Validation Methods | 10 | FILE_CATALOG.md + SESSION_CONTEXT (CBV) |
| Soft Data Management | 7 | FILE_CATALOG.md + 2softdata/README.md |
| Visualization & Plotting | 11 | FILE_CATALOG.md + README_diagnostic_visualization.md |
| Diagnostic Tools | 12 | FILE_CATALOG.md + ANALYSIS_neighbours_stg_crash.md |
| Utilities & Helpers | 5 | FILE_CATALOG.md |
| Examples & Tests | 7 | FILE_CATALOG.md |

---

## 🚀 For New Claude Code Sessions

**Recommended workflow for continuing work:**

1. **Feed context file:**
   - Upload or reference `SESSION_CONTEXT_CBV_IMPLEMENTATION.md`
   - This contains all recent work and context

2. **Use FILE_CATALOG.md as reference:**
   - Lookup specific files as needed
   - Understand file purposes and relationships

3. **Check README.md for:**
   - BME method codes
   - Configuration parameters
   - Common workflows

4. **Refer to specialized docs as needed:**
   - Diagnostics → README_diagnostic_visualization.md
   - Multi-dataset kriging → README_krigingME_stug_multi.md
   - Crash debugging → ANALYSIS_neighbours_stg_crash.md

---

## 📝 Documentation Maintenance

### When to Update Documentation

**Update SESSION_CONTEXT when:**
- Completing a major implementation
- Fixing significant bugs
- Adding new functionality
- Before ending a Claude Code session

**Update FILE_CATALOG when:**
- Adding new .m files
- Significantly changing file functionality
- Reorganizing file structure

**Update README when:**
- Changing project scope
- Adding new workflows
- Updating installation instructions
- Adding new BME method codes

**Create new specialized docs when:**
- Implementing complex new features
- Documenting detailed analyses
- Creating new subsystems

---

## 🔗 External References

- **BMELIB:** http://faculty.sites.uci.edu/tbmeehan/
- **TOAR Database:** https://toar-data.org/
- **GitHub Issues:** (if applicable)

---

## 📄 File Naming Conventions

**Documentation files:**
- `README.md` - Main project documentation
- `README_<topic>.md` - Topic-specific guides
- `ANALYSIS_<topic>.md` - Detailed technical analyses
- `SESSION_CONTEXT_<topic>.md` - Session context captures
- `FILE_CATALOG.md` - Complete file inventory
- `DOCUMENTATION_INDEX.md` - This file

**MATLAB files:**
- `getTOAR*.m` - Data loading/processing
- `est*.m` - Estimation functions
- `kriging*.m` - Kriging algorithms
- `plot*.m` - Visualization functions
- `validate*.m` - Validation methods
- `example_*.m` - Example scripts
- `test_*.m` - Test scripts

---

## 💾 Repository Statistics

- **Total MATLAB files:** 89
- **Documentation files:** 8 (main) + several supporting
- **Total lines of documentation:** ~3,000+
- **Last major update:** January 17, 2026 (CBV implementation)
- **Git branch:** `claude/review-codebase-01WkRHYz215aooREUrKMP4rh`

---

## ✅ Documentation Completeness Checklist

- ✅ Main README with project overview
- ✅ Complete file catalog (all 89 files)
- ✅ Session context for latest work
- ✅ Diagnostic visualization guide
- ✅ Multi-dataset kriging guide
- ✅ neighbours_stg crash analysis
- ✅ Soft data integration guide
- ✅ HPC validation guide
- ✅ Master documentation index (this file)
- ✅ Cross-references between docs
- ✅ Quick reference sections
- ✅ Code examples throughout
- ✅ Troubleshooting guides

---

## 🎯 Next Steps for Documentation

**Potential future additions:**
- API reference (auto-generated from headers)
- Tutorial notebooks/live scripts
- Video walkthroughs
- Performance benchmarking results
- Case studies and applications
- Developer contribution guide

---

**End of Documentation Index**

*Use this index to navigate all project documentation. For questions or to report documentation gaps, please file an issue or contact the development team.*

**Quick Links:**
- [README.md](README.md) - Start here
- [FILE_CATALOG.md](FILE_CATALOG.md) - Find any file
- [SESSION_CONTEXT_CBV_IMPLEMENTATION.md](SESSION_CONTEXT_CBV_IMPLEMENTATION.md) - Latest work
