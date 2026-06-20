# Environment Setup Runbook — SARS-CoV-2 Ion Torrent Pipeline

This document records the **complete process** used to set up this project from
scratch: GitHub creation through a fully working conda + R + Python environment
on Zorin OS (Ubuntu-based). It includes every error encountered during the real
setup, why each one happened, and exactly how it was fixed — so the same problems
can be solved in minutes instead of hours if they recur, on this machine or any
other.

No single person memorizes all of this in advance. What's reusable is the
**diagnostic method**, not the specific fixes. That method is described first;
the fixes follow as a reference log.

---

## Part 1 — The Diagnostic Method

Almost every environment-setup error in bioinformatics falls into one of five
categories. When something fails, check in this order:

1. **Network/connectivity** — Did the download actually complete? Look for
   `ConnectionResetError`, `IncompleteRead`, or timeouts. Fix: increase conda's
   timeout/retry settings, or simply rerun the same command (conda resumes).

2. **Missing system library (runtime)** — A compiled tool can't find a shared
   library at *run* time. Look for `error while loading shared libraries` or
   `cannot find -lXXX` during linking. Fix: install the library, either via
   `apt` (system-wide) or, preferably in a conda environment, via
   `conda install -c conda-forge <libname>`.

3. **Missing development headers (compile time)** — A package compiles C/C++
   code and can't find a `.h` header file. Look for `fatal error: xxx.h: No
   such file or directory`. Fix: install the `-dev`/`-devel` package, or the
   conda equivalent.

4. **Wrong library found (version/path conflict)** — The *system* version of a
   library is found instead of the *conda* version (or vice versa), causing
   either a version mismatch or missing symbols. Look for `undefined reference
   to` errors naming functions, or a configure script reporting an unexpectedly
   old version. Fix: check `pkg-config --modversion <lib>` and
   `which <tool>` — if they point to `/usr/...` instead of
   `.../miniconda3/envs/...`, fix `PKG_CONFIG_PATH` or `PATH` ordering.

5. **Cascading dependency failure** — One package's failure causes 10 others
   to fail with "dependency X is not available." Always scroll up (or grep) to
   find the *first* failure — fixing that one fixes the rest automatically.

**The single most useful diagnostic habit**: when 10+ packages fail at once,
don't try to fix all 10. Find the *one* package at the root of the dependency
tree and retry installing just that one in isolation to see its real error.

---

## Part 2 — Full Setup Sequence (What We Actually Did)

### 2.1 GitHub repository creation
1. Created public repo on github.com with README, `.gitignore` (Python
   template), and MIT License.
2. Generated an SSH key on the local machine:
   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com"
   cat ~/.ssh/id_ed25519.pub
   ```
3. Added the public key under GitHub → Settings → SSH and GPG keys.
4. Verified with `ssh -T git@github.com` — must show
   `Hi <username>! You've successfully authenticated`.

   **Mistake made:** initially ran `ssh -T git@github.com` before adding the
   key to GitHub, got `Permission denied (publickey)`. This is expected and
   not a bug — the key has to be added to GitHub first.

5. Cloned the repo locally:
   ```bash
   git clone git@github.com:USERNAME/REPO_NAME.git
   ```

### 2.2 Directory structure and foundation files
Created the full pipeline folder structure (`data/`, `results/`, `scripts/`,
`envs/`, `config/`, `docs/`, `.github/workflows/`) and populated it with:
- `config/pipeline_config.yaml` — single source of truth for all parameters
- `envs/environment.yml` — conda environment definition
- `envs/r_packages.R` — R/Bioconductor package installer
- `scripts/bash/run_pipeline.sh` — master pipeline controller
- `scripts/bash/00_setup.sh` — pre-flight environment checker
- `scripts/python/utils/logger.py` — structured audit logger
- `scripts/R/utils/theme_publication.R` — shared ggplot2 theme
- `data/metadata/sample_metadata.csv` — real sample manifest
- `.github/workflows/validate_env.yml` — CI validation

**Mistake made:** initial attempt used `mkdir -p {a,b,c}` brace expansion
inside a single string that had already been through variable substitution,
creating literal folders named `{data/{raw,reference,...}}` instead of
expanding properly. Fixed by writing out each `mkdir -p` path explicitly
rather than relying on nested brace expansion.

**Mistake made:** initial sample metadata used placeholder names
(`IonCode_0101` etc.) instead of the user's real BAM filenames
(`bauchi_1586.bam`, `kano_0103.bam`, etc.). Always derive the metadata
template directly from `ls data/raw/*.bam` rather than inventing names.

All foundation files were committed and pushed:
```bash
git add .
git commit -m "feat: add pipeline foundation"
git push origin main
```

### 2.3 Conda installation
Conda was already present (`conda 25.7.0`) — Miniconda install step was
skipped. If conda is not present:
```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
source ~/.bashrc
```

### 2.4 Building the conda environment — incrementally
**Mistake made:** the original `environment.yml` pinned an exact Bioconductor
package version (`bioconductor-ggtree=3.8.2`) directly in the conda
dependency list. That exact build was not available in the channel, so
`conda env create` failed at the solve step before installing anything.

**Fix:** removed all Bioconductor packages from `environment.yml` entirely —
Bioconductor packages should be installed through R's own package manager
(`BiocManager`), not through conda's R channel, because conda's Bioconductor
builds lag behind and pin awkwardly. Also relaxed most strict `=x.y.z`
version pins to unpinned packages, letting conda's solver pick compatible
versions.

**Mistake made / recurring issue:** `conda env create` repeatedlydropped
mid-download with errors like:
```
ConnectionResetError(104, 'Connection reset by peer')
IncompleteRead(8900736 bytes read, 1448378 more expected)
```
This is pure network instability, not a config problem.

**Fix 1 (timeouts):**
```bash
conda config --set remote_read_timeout_secs 120
conda config --set remote_connect_timeout_secs 60
conda config --set remote_max_retries 10
```

**Fix 2 (strategy):** Instead of one large `conda env create` (which restarts
the whole solve from scratch on any failure), the environment was built
**incrementally**:
```bash
conda create -n sarscov2-pipeline python=3.9 -y
conda activate sarscov2-pipeline
conda install -c bioconda -c conda-forge fastqc multiqc -y
conda install -c bioconda -c conda-forge trimmomatic bwa samtools -y
conda install -c bioconda -c conda-forge mosdepth ivar bedtools -y
conda install -c bioconda -c conda-forge mafft iqtree -y
conda install -c conda-forge pandas numpy matplotlib seaborn -y
conda install -c conda-forge biopython pysam scipy pyyaml -y
conda install -c conda-forge jupyter jupyterlab rich click -y
conda install -c conda-forge r-base r-essentials -y
conda install -c conda-forge r-ggplot2 r-dplyr r-tidyr r-readr -y
conda install -c conda-forge r-patchwork r-cowplot r-viridis r-knitr r-rmarkdown -y
```
**Lesson:** if a batch dropped mid-download, the exact same command was simply
rerun — conda resumes/retries cleanly rather than restarting from zero. Small
batches mean a dropped connection only wastes a minute, not twenty.

**Mistake made:** `which multiqc` returned `/usr/bin/multiqc` (a broken
system-wide install with an incompatible NumPy) even while the conda
environment was active. This happened because the conda env's own `multiqc`
hadn't actually finished installing in an earlier interrupted batch — bash had
cached the wrong PATH resolution.

**Fix:**
```bash
hash -r                     # clear bash's command path cache
conda list | grep -i multiqc   # confirm it's actually missing from the env
conda install -c bioconda -c conda-forge multiqc -y   # reinstall into the env
```
**Lesson:** `which <tool>` and `hash -r` are the first two commands to run
whenever a tool behaves unexpectedly even though "the right environment is
active."

### 2.5 R package installation — the hard part
Running `Rscript envs/r_packages.R` failed on roughly 14 packages, falling
into three groups. Each is logged separately because the diagnostic process
differed.

#### Group A — Spatial packages (`sf`, `units`, `lwgeom`, `leaflet`, `tmap`, `spdep`)

**Error 1:**
```
configure: error: libudunits2.so was not found
```
**Cause:** `units` (a dependency of `sf`) needs the `udunits2` C library.
**Fix:**
```bash
conda install -c conda-forge udunits2 -y
```

**Error 2 (after fixing udunits2):**
```
/usr/lib/libgdal.so: undefined reference to `nc_inq_user_type'
ld: cannot find -lheif / -lpoppler / -lgeos_c / -lproj / ... (15+ missing libs)
```
**Cause:** R's compiler (from conda) was linking against the **system**
GDAL at `/usr/lib/libgdal.so`, which itself depends on a long chain of
system libraries that weren't all present, and which is generally
ABI-incompatible with conda's toolchain.
**Fix:** install GDAL (and its full dependency chain) through conda instead,
so R links against a self-contained, compatible build:
```bash
conda install -c conda-forge gdal libgdal geos proj -y
```
After this, `install.packages(c("units","sf"))` succeeded cleanly.

**Error 3 (installing `lwgeom`):**
```
configure: PROJ: 8.2.1
checking PROJ: checking whether linking against PROJ works:... no
configure: error: libproj not found in standard or given locations.
```
**Cause:** `sf` had correctly linked against conda's PROJ **9.7.1**, but
`lwgeom`'s configure script used `pkg-config`, which was resolving to the
**system** PROJ **8.2.1** at `/usr/lib/x86_64-linux-gnu/pkgconfig/proj.pc`,
because `PKG_CONFIG_PATH` was empty and pkg-config fell back to its default
system search path.
**Diagnosis commands used:**
```bash
pkg-config --modversion proj      # showed 8.2.1 (wrong)
find / -name "proj.pc" 2>/dev/null   # showed both system and conda .pc files
```
**Fix:**
```bash
export PKG_CONFIG_PATH="$CONDA_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
pkg-config --modversion proj      # now correctly shows 9.7.1
```
This single fix also unblocked `tmaptools` and `tmap`, which both depend on
`lwgeom`/`sf`.

**Lesson:** when a configure script reports an unexpectedly *old* version of
a library that you know you installed a newer version of via conda, the
almost-certain cause is `PKG_CONFIG_PATH` (or equivalently `PATH` /
`LD_LIBRARY_PATH`) resolving to the system copy first.

**Permanent fix** — added to `~/.bashrc` so it persists across terminal
sessions:
```bash
echo 'export PKG_CONFIG_PATH="/home/stephen/miniconda3/envs/sarscov2-pipeline/lib/pkgconfig:$PKG_CONFIG_PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### Group B — Document/table packages (`V8`, `juicyjuice`, `gt`, `gtsummary`)

**Error:**
```
ld: cannot find -lv8: No such file or directory
```
**Cause:** the R `V8` package needs Google's V8 JavaScript engine library,
which was never actually present on the system (only a stray header at
`/usr/include/v8` existed, no compiled library).
**Attempted fix:** `conda install -c conda-forge v8 -y` →
```
PackagesNotFoundError: The following packages are not available from current channels: v8
```
**Resolution:** abandoned this dependency rather than chasing it further,
since it is not required for any core pipeline step. Removed `V8`,
`juicyjuice`, `gt`, `gtsummary`, `katex`, `equatags`, `kableExtra` from
`envs/r_packages.R`. Substituted `flextable` (already installed
successfully) and base `knitr::kable()` for publication tables instead —
both have zero compiled/system dependencies.

**Lesson:** not every failed package is worth fixing. If a package is purely
cosmetic (nicer tables) and a zero-dependency alternative exists, the
professional choice is to substitute, document the decision, and move on —
not to burn hours chasing an unavailable system library.

#### Group C — Bioconductor packages (`ggtree`, `ComplexHeatmap`, `Rsamtools`, `trackViewer`, `ggmsa`)

**Error 1:**
```
Error: Bioconductor version '3.18' requires R version '4.3';
use `version = '3.22'` with R version 4.5
```
**Cause:** conda installed a newer R (4.5.3) than the `r_packages.R` script
assumed (4.3.1), so the hardcoded Bioconductor version string was wrong.
**Fix:**
```bash
sed -i 's/BiocManager::install(version="3.18")/BiocManager::install(version="3.22")/' envs/r_packages.R
```
**Lesson:** Bioconductor version must always match the installed R version —
check `R --version` and cross-reference against the
[Bioconductor release table](https://bioconductor.org/about/release-announcements/)
rather than assuming.

**Error 2 (root cause of a 12-package cascade):**
```
hts.c:46:10: fatal error: lzma.h: No such file or directory
ERROR: compilation failed for package 'Rhtslib'
ERROR: dependency 'Rhtslib' is not available for package 'Rsamtools'
ERROR: dependency 'Rsamtools' is not available for package 'GenomicAlignments'
ERROR: dependencies '...' are not available for 'rtracklayer'
... (continues cascading through BSgenome, GenomicFeatures, VariantAnnotation,
     ensembldb, txdbmaker, biovizBase, Gviz, trackViewer)
```
**Cause:** `Rhtslib` (which wraps the same `htslib` C library samtools itself
uses) needs the **liblzma development header** (`lzma.h`) to compile. The
*runtime* `liblzma` library existed, but the header did not.
**Diagnosis approach:** rather than trying to fix all 12 failed packages,
isolated and reinstalled just the root package to see its real error:
```bash
Rscript -e 'BiocManager::install("Rsamtools", ask=FALSE, update=FALSE)' 2>&1 | tail -60
```
This surfaced the actual `lzma.h` error hidden under 12 layers of cascade
messages.
**Fix:**
```bash
conda install -c conda-forge xz -y    # xz provides both liblzma and lzma.h
```
Reran the `Rsamtools` install — succeeded. Rerunning the original 5-package
install then succeeded for everything else too, since the entire dependency
tree was now unblocked.

**Lesson:** when N packages fail with "dependency X not available," **always
isolate and reinstall X alone** to see its real, undisguised error message.
Fixing the root almost always cascades to fixing everything downstream
automatically — no need to debug each of the 12 failures individually.

### 2.6 Reference genome and indexing
```bash
wget "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=NC_045512.2&rettype=fasta&retmode=text" \
     -O data/reference/NC_045512.2.fasta
bwa index data/reference/NC_045512.2.fasta
samtools faidx data/reference/NC_045512.2.fasta
```
Verified: 1 sequence, ~29,903 bp genome, all six BWA/samtools index files
created (`.amb .ann .bwt .fai .pac .sa`). No errors encountered at this step.

---

## Part 2.7 — Pre-flight Script and Pipeline Run Issues (Post-Environment-Setup)

These issues surfaced after the conda/R environment was fully working, while
validating the pipeline scripts themselves and preparing real data to run.

### Bash arithmetic increment killing the script under `set -e`

**Symptom:** `00_setup.sh` silently stopped after printing exactly one ✅ line,
with no error message at all.
**Diagnosis approach:** reran with `bash -x scripts/bash/00_setup.sh` to print
every command before execution, which showed the script exiting immediately
after `(( PASS++ ))`.
**Cause:** in bash, `((expr))` returns a *non-zero exit status* (i.e. "failure")
whenever `expr` evaluates to `0`. `PASS` starts at `0`, so the very first
`((PASS++))` evaluates the *pre-increment* value (`0`) as the command's exit
status, which `set -e` treats as a fatal error and kills the script — even
though the increment itself works correctly.
**Fix:**
```bash
sed -i 's/((PASS++))/((PASS++)) || true/g' scripts/bash/00_setup.sh
sed -i 's/((WARN++))/((WARN++)) || true/g' scripts/bash/00_setup.sh
sed -i 's/((FAIL++))/((FAIL++)) || true/g' scripts/bash/00_setup.sh
```
**Lesson:** any `((var++))` on a counter that may legitimately be `0` is unsafe
under `set -e`. Either append `|| true`, or use `: $((var++))` (the leading
`:` is a no-op command that always succeeds, swallowing the arithmetic
expression's exit status), or switch to `var=$((var+1))` which never triggers
this behaviour since plain assignment doesn't set an exit status from the
value.

### Binary name mismatch: `iqtree2` vs `iqtree`

**Symptom:** pre-flight check reported `iqtree2 not found` despite IQ-TREE
having installed successfully via conda.
**Cause:** the conda-forge build of IQ-TREE installs the binary as `iqtree`,
not `iqtree2`, even though the package itself may be the IQ-TREE2 codebase.
Binary names vary across distribution channels and aren't always consistent
with the project/package name.
**Diagnosis:**
```bash
which iqtree2 2>/dev/null || which iqtree 2>/dev/null
```
**Fix:** updated all scripts to reference the actual installed binary name:
```bash
sed -i 's/iqtree2/iqtree/g' scripts/bash/00_setup.sh
sed -i 's/iqtree2/iqtree/g' scripts/bash/run_pipeline.sh
```
**Lesson:** never assume a tool's command-line binary name matches its
package name or its commonly-used name in papers/documentation. Always
verify with `which <tool>` or `command -v <tool>` after installing, and
check `<tool> --version` / `<tool> --help` to confirm it's actually the
program intended.

### Nextclade dataset: CLI timeout and corrupted bulk zip download

**Symptom 1:** `nextclade dataset get` failed with:
```
Error: error decoding response body / operation timed out
```
**Cause:** same underlying network instability seen throughout conda
installs — large file transfer over an unstable connection.
**Attempted fix:** `nextclade dataset get ... --timeout 120` (increases the
CLI's internal timeout) — still failed in this case.

**Symptom 2 (fallback attempt):** downloaded the entire
`nextclade_data` GitHub repo as a zip (~67MB) via `wget` directly, which
completed and reported `200 OK`, but `unzip` then failed:
```
End-of-central-directory signature not found.
```
and Python's `zipfile` module raised `BadZipFile: File is not a zip file`.
**Cause:** despite `wget` reporting success, the download was silently
truncated/corrupted — large files over flaky connections can complete the
HTTP transaction without all bytes arriving intact, and neither `wget` nor
the OS necessarily catches this without a checksum comparison.
**Resolution:** abandoned the bulk zip approach entirely. Instead,
downloaded only the handful of small individual files Nextclade actually
needs, directly from `raw.githubusercontent.com`, one at a time:
```bash
BASE="https://raw.githubusercontent.com/nextstrain/nextclade_data/master/data/nextstrain/sars-cov-2/wuhan-hu-1/orfs"
wget --timeout=60 --tries=3 "${BASE}/pathogen.json"           -O data/reference/nextclade_dataset/pathogen.json
wget --timeout=60 --tries=3 "${BASE}/reference.fasta"          -O data/reference/nextclade_dataset/reference.fasta
wget --timeout=60 --tries=3 "${BASE}/genome_annotation.gff3"   -O data/reference/nextclade_dataset/genome_annotation.gff3
wget --timeout=60 --tries=3 "${BASE}/sequences.fasta"          -O data/reference/nextclade_dataset/sequences.fasta
wget --timeout=60 --tries=3 "${BASE}/tree.json"                -O data/reference/nextclade_dataset/tree.json
wget --timeout=60 --tries=3 "${BASE}/clades.tsv"                -O data/reference/nextclade_dataset/clades.tsv
```
All downloaded successfully and `nextclade run --input-dataset ...` correctly
recognised the resulting folder as a valid dataset.
**Lesson:** when a large bulk download is unreliable on a poor connection,
check whether the tool actually needs the *entire* archive or just a handful
of specific files within it — fetching those individually is far more
resilient, since each small download either fully succeeds or fails fast,
rather than silently corrupting partway through a large transfer.
**Secondary lesson:** `file <name>.zip` reporting "Zip archive data" is
**not** proof the file is complete or valid — it only inspects the file's
magic-byte header, not its internal structure/central directory. Always
verify a downloaded archive with `unzip -t` or by attempting to actually
read it (e.g. Python's `zipfile.ZipFile(...)`) rather than trusting `file`.

### Stale conda environment state across terminal sessions

**Symptom:** pre-flight check that had previously shown all green suddenly
reported 7 failures (`trimmomatic`, `mosdepth`, `nextclade`, `iqtree`,
`python`, `Rscript` all "not found"), despite nothing having changed.
**Cause:** simply opened a new terminal / returned to the project after a
break without re-running `conda activate sarscov2-pipeline`. The prompt no
longer showed the `(sarscov2-pipeline)` prefix, confirming the base
environment was active instead.
**Fix:**
```bash
conda activate sarscov2-pipeline
bash scripts/bash/00_setup.sh
```
**Lesson:** conda environments do **not** persist automatically across new
terminal sessions or after closing/reopening a terminal — `conda activate`
must be rerun every time. Before troubleshooting a sudden wave of "tool not
found" errors, always check the shell prompt for the environment name, or
run `echo $CONDA_DEFAULT_ENV`, before assuming something is actually broken.

### Disk space exhaustion risk before first real pipeline run

**Symptom:** pre-flight check passed everything except a disk space warning
— only 19GB free with 50GB recommended, against ~14GB of BAM files alone
plus pipeline-generated intermediate files still to come (trimmed FASTQs,
realigned BAMs, variant tables, consensus FASTAs).
**Diagnosis:**
```bash
df -h
du -sh ~/* 2>/dev/null | sort -rh | head -15
du -sh ~/Desktop/* 2>/dev/null | sort -rh
```
**Cause:** accumulation of old/duplicate files unrelated to the current
project: six duplicate copies of the Miniconda installer script (~660MB),
1.6GB of pip/conda cache, and — the largest single item — a 28GB folder of
already-superseded BAM files and prior analysis outputs that were fully
duplicated elsewhere and had already been migrated into the new project
structure.
**Fix:**
```bash
rm ~/Miniconda3-latest-Linux-x86_64.sh*
rm ~/Miniconda3-py39_24.1.2-0-Linux-x86_64.sh*
conda clean --all -y
rm -rf ~/.cache/pip
rm -rf ~/Desktop/HIGH_QUALITY_FASTA_FILES   # confirmed fully duplicated elsewhere first
```
Freed disk space from 19GB to 55GB available.
**Lesson:** before deleting any large folder suspected of being redundant,
explicitly enumerate its contents (`find <dir> -type f`) rather than trusting
the folder name alone — in this case the folder turned out to contain not
just raw BAM files but also prior Nextclade analysis results, mutation
tables, and a consensus FASTA, which were genuinely valuable and needed a
conscious "yes, these are duplicated elsewhere" confirmation before deletion,
not an assumption based on the directory name.

---

## Part 3 — Quick Diagnostic Reference Table

| Symptom | Likely cause | First commands to run |
|---|---|---|
| `ConnectionResetError` / `IncompleteRead` | Network instability | Rerun the exact same install command |
| `command not found` for an installed tool | PATH/env not active, or stale bash cache | `conda activate <env>`, then `hash -r`, then `which <tool>` |
| `cannot find -lXXX` at link time | Runtime library missing from conda env | `conda install -c conda-forge <libname>` |
| `fatal error: xxx.h: No such file` | Dev headers missing | `conda install -c conda-forge <libname>` (often same pkg provides both) |
| configure reports an old version you didn't install | Wrong `PKG_CONFIG_PATH`/`PATH` order | `pkg-config --modversion <lib>`, fix `PKG_CONFIG_PATH` |
| 10+ packages fail citing each other as missing deps | One root package failed | Reinstall the root package alone, read its real error |
| Bioconductor version mismatch error | R version changed since script was written | Check `R --version`, match against Bioconductor's release table |
| Package install fails and isn't core to the pipeline | Not worth chasing | Substitute a zero-dependency alternative, document, move on |
| Script dies silently with no error after one line, `set -e` is active | A `((counter++))` hit zero and was read as failure | Add `\|\| true`, or use `var=$((var+1))` instead |
| "Tool not found" for many tools at once, nothing changed | Conda env not active in this terminal | `echo $CONDA_DEFAULT_ENV`, then `conda activate <env>` |
| Large `wget` download reports success but `unzip`/parsing fails | Silent truncation/corruption over a slow connection | Don't trust `file`'s "Zip archive data" verdict; verify with `unzip -t` or re-fetch only the specific small files actually needed |

---

## Part 4 — What to Read to Build This Skill Properly

This is not knowledge any one person holds complete in their head — it's a
skill built from documentation literacy plus repetition. Useful material:

- **Conda documentation** — environment management, channel priority, and
  the `conda config` options used here (timeouts/retries):
  https://docs.conda.io/projects/conda/en/latest/
- **Bioconductor support site** — the single best place to search an exact
  Bioconductor error message; almost every error here has been hit by
  someone else and answered: https://support.bioconductor.org/
- **r-spatial documentation** for `sf`/`lwgeom`/installation issues
  specifically (this ecosystem has unusually good install troubleshooting
  docs because the GDAL/GEOS/PROJ dependency chain is notoriously fragile):
  https://r-spatial.github.io/sf/#installing
- **Conda-forge feedstocks** on GitHub — when a conda package fails to
  solve or is missing, the feedstock repo (search
  `conda-forge/<package>-feedstock`) often documents known platform issues.
- **Stack Overflow + exact error text** — for any `fatal error: xxx.h` or
  `cannot find -lxxx` message, searching the *exact* missing filename
  (`lzma.h`, `proj.h`, etc.) plus "R package install" surfaces the answer
  extremely reliably, since these are common, well-documented patterns.
- **`man pkg-config`** and **`man ld`** — worth reading once end-to-end;
  most "mystery" compilation errors are pkg-config or linker path issues in
  disguise, and understanding these two tools demystifies most of them.

The realistic path to "knowing this" is: hit the error, search the exact
error text, understand *why* the fix worked (not just that it worked), and
write it down. After 15–20 repetitions across projects, the five categories
in Part 1 become pattern-recognition rather than research.

---

*This document should be updated any time a new environment issue is solved,
so the runbook stays a living reference rather than a one-time snapshot.*
