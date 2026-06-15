#!/usr/bin/env bash
# Pre-flight check — run before pipeline
set -euo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0; WARN=0; FAIL=0

log_pass() { echo -e "${GREEN}  ✅ $*${NC}"; ((PASS++)); }
log_warn() { echo -e "${YELLOW}  ⚠️  $*${NC}"; ((WARN++)); }
log_fail() { echo -e "${RED}  ❌ $*${NC}"; ((FAIL++)); }
section()  { echo -e "\n${BOLD}${BLUE}── $* ──────────────────────────${NC}"; }

echo -e "${BOLD}  Pipeline Pre-flight Check${NC}"

section "Conda Environment"
if [[ "${CONDA_DEFAULT_ENV:-}" == "sarscov2-pipeline" ]]; then
  log_pass "sarscov2-pipeline is active"
else
  log_fail "Run: conda activate sarscov2-pipeline"
fi

section "Required Tools"
for tool in fastqc trimmomatic bwa samtools mosdepth ivar nextclade mafft iqtree2 multiqc python Rscript; do
  if command -v "$tool" &>/dev/null; then
    log_pass "$tool found"
  else
    log_fail "$tool not found"
  fi
done

section "Reference Genome"
REF="${REPO_ROOT}/data/reference/NC_045512.2.fasta"
if [[ -f "$REF" ]]; then
  log_pass "Reference genome found"
  [[ -f "${REF}.bwt" ]] && log_pass "BWA index exists" || log_warn "BWA index missing — run: bwa index $REF"
else
  log_warn "Reference not found — will be downloaded on first run"
fi

section "Nextclade Dataset"
if [[ -d "${REPO_ROOT}/data/reference/nextclade_dataset" ]]; then
  log_pass "Nextclade dataset found"
else
  log_warn "Nextclade dataset missing — run: nextclade dataset get --name sars-cov-2 --output-dir data/reference/nextclade_dataset"
fi

section "BAM Files"
BAM_DIR="${REPO_ROOT}/data/raw"
bam_count=$(find "$BAM_DIR" -name "*.bam" 2>/dev/null | wc -l)
if [[ "$bam_count" -gt 0 ]]; then
  log_pass "Found $bam_count BAM file(s)"
  find "$BAM_DIR" -name "*.bam" | while read -r b; do
    echo -e "         → $(basename "$b") ($(du -sh "$b" | cut -f1))"
  done
else
  log_warn "No BAM files in data/raw/ — copy your BAM files there"
fi

section "Sample Metadata"
META="${REPO_ROOT}/data/metadata/sample_metadata.csv"
if [[ -f "$META" ]]; then
  n=$(tail -n +2 "$META" | grep -v '^$' | wc -l)
  log_pass "Metadata found: $n samples"
else
  log_fail "No metadata file — copy template: cp data/metadata/sample_metadata_TEMPLATE.csv data/metadata/sample_metadata.csv"
fi

section "Disk Space"
available=$(df -BG "$REPO_ROOT" | awk 'NR==2 {print $4}' | tr -d 'G')
[[ "$available" -ge 50 ]] && log_pass "${available}GB available" || log_warn "${available}GB available (50GB recommended)"

echo -e "\n${BOLD}══════════════════════════════════${NC}"
echo -e "${BOLD}  PASS: ${GREEN}$PASS${NC}  WARN: ${YELLOW}$WARN${NC}  FAIL: ${RED}$FAIL${NC}"
[[ "$FAIL" -eq 0 ]] && echo -e "${GREEN}${BOLD}  ✅ Ready to run!${NC}" || echo -e "${RED}${BOLD}  ❌ Fix $FAIL error(s) first${NC}"
