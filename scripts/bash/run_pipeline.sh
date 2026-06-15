#!/usr/bin/env bash
# Master pipeline controller
set -euo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
METADATA="${REPO_ROOT}/data/metadata/sample_metadata.csv"
AUDIT_LOG="${REPO_ROOT}/audit.log"
RESULTS="${REPO_ROOT}/results"
PIPELINE_VERSION="1.0.0"
RUN_ID="run_$(date +%Y%m%d_%H%M%S)"
SAMPLE=""; RUN_ALL=false; RUN_COHORT=false; RESUME=false
MODULES="qc,align,variants,consensus,lineage"; DRY_RUN=false

show_help() {
cat << HELP
SARS-CoV-2 Pipeline v${PIPELINE_VERSION}
Usage:
  --sample SAMPLE_ID    Process one sample
  --all                 Process all samples
  --cohort              Run cohort analysis
  --modules LIST        Comma-separated: qc,align,variants,consensus,lineage
  --resume              Skip completed steps
  --dry-run             Print commands only
  -h, --help            This help
HELP
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --sample)   SAMPLE="$2";      shift 2 ;;
    --all)      RUN_ALL=true;     shift   ;;
    --cohort)   RUN_COHORT=true;  shift   ;;
    --modules)  MODULES="$2";     shift 2 ;;
    --resume)   RESUME=true;      shift   ;;
    --dry-run)  DRY_RUN=true;     shift   ;;
    -h|--help)  show_help; exit 0         ;;
    *)          echo "Unknown: $1"; exit 1;;
  esac
done

log()   { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ $*${NC}"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*" >> "$AUDIT_LOG"; }
warn()  { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️  $*${NC}"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $*" >> "$AUDIT_LOG"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ❌ $*${NC}"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "$AUDIT_LOG"; exit 1; }
info()  { echo -e "${CYAN}[$(date '+%H:%M:%S')] ℹ️  $*${NC}"; }
step()  { echo -e "\n${BOLD}${BLUE}━━━━ $* ━━━━${NC}"; }

run_cmd() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CMD] $*" >> "$AUDIT_LOG"
  [[ "$DRY_RUN" == true ]] && echo -e "${YELLOW}[DRY-RUN] $*${NC}" || eval "$@"
}

is_done()  { [[ "$RESUME" == true ]] && [[ -f "$1" ]]; }
mark_done(){ touch "$1"; }

get_all_samples() { tail -n +2 "$METADATA" | cut -d',' -f1 | grep -v '^$'; }
get_bam()        { tail -n +2 "$METADATA" | awk -F',' -v s="$1" '$1==s{print $2}' | head -1; }

module_qc() {
  local sample="$1" bam="${REPO_ROOT}/data/raw/$2"
  local out="${RESULTS}/qc"; local done="${out}/.done_${sample}_qc"
  is_done "$done" && { info "QC done ($sample) — skipping"; return; }
  step "QC — $sample"
  mkdir -p "${out}/fastqc" "${out}/flagstat"
  run_cmd "fastqc '$bam' -o '${out}/fastqc' -t 4 --quiet"
  run_cmd "samtools flagstat '$bam' > '${out}/flagstat/${sample}_flagstat.txt'"
  mark_done "$done"; log "QC complete — $sample"
}

module_align() {
  local sample="$1" bam="${REPO_ROOT}/data/raw/$2"
  local ref="${REPO_ROOT}/data/reference/NC_045512.2.fasta"
  local out="${RESULTS}/alignment/${sample}"; local done="${out}/.done_${sample}_align"
  is_done "$done" && { info "Alignment done ($sample) — skipping"; return; }
  step "Alignment — $sample"; mkdir -p "$out" "${RESULTS}/alignment/coverage/${sample}"
  run_cmd "samtools bam2fq '$bam' > '${out}/${sample}.fastq'"
  run_cmd "trimmomatic SE -threads 4 -phred33 '${out}/${sample}.fastq' '${out}/${sample}_trimmed.fastq' SLIDINGWINDOW:4:20 LEADING:3 TRAILING:3 MINLEN:50"
  [[ ! -f "${ref}.bwt" ]] && run_cmd "bwa index '$ref'"
  run_cmd "bwa mem -t 8 '$ref' '${out}/${sample}_trimmed.fastq' > '${out}/${sample}.sam'"
  run_cmd "samtools sort -o '${out}/${sample}_sorted.bam' '${out}/${sample}.sam'"
  run_cmd "samtools index '${out}/${sample}_sorted.bam'"
  run_cmd "rm '${out}/${sample}.sam'"
  run_cmd "mosdepth -n --fast-mode --by 500 '${RESULTS}/alignment/coverage/${sample}/${sample}' '${out}/${sample}_sorted.bam'"
  mark_done "$done"; log "Alignment complete — $sample"
}

module_variants() {
  local sample="$1"
  local bam="${RESULTS}/alignment/${sample}/${sample}_sorted.bam"
  local ref="${REPO_ROOT}/data/reference/NC_045512.2.fasta"
  local out="${RESULTS}/variants/${sample}"; local done="${out}/.done_${sample}_variants"
  is_done "$done" && { info "Variants done ($sample) — skipping"; return; }
  step "Variant Calling — $sample"; mkdir -p "$out"
  run_cmd "samtools mpileup -aa -A -d 0 -B -Q 0 '$bam' | ivar variants -p '${out}/${sample}_variants' -q 20 -t 0.03 -m 10 -r '$ref'"
  mark_done "$done"; log "Variants complete — $sample"
}

module_consensus() {
  local sample="$1"
  local bam="${RESULTS}/alignment/${sample}/${sample}_sorted.bam"
  local out="${RESULTS}/consensus/${sample}"; local done="${out}/.done_${sample}_consensus"
  is_done "$done" && { info "Consensus done ($sample) — skipping"; return; }
  step "Consensus — $sample"; mkdir -p "$out"
  run_cmd "samtools mpileup -aa -A -d 0 -B -Q 0 '$bam' | ivar consensus -p '${out}/${sample}' -t 0.5 -n N -m 10"
  [[ -f "${out}/${sample}.fa" ]] && run_cmd "mv '${out}/${sample}.fa' '${out}/${sample}.fasta'"
  mark_done "$done"; log "Consensus complete — $sample"
}

module_lineage() {
  local sample="$1"
  local fasta="${RESULTS}/consensus/${sample}/${sample}.fasta"
  local out="${RESULTS}/nextclade/${sample}"; local done="${out}/.done_${sample}_lineage"
  is_done "$done" && { info "Lineage done ($sample) — skipping"; return; }
  step "Lineage — $sample"; mkdir -p "${out}/nextclade" "${out}/pangolin"
  run_cmd "nextclade run -D '${REPO_ROOT}/data/reference/nextclade_dataset' -O '${out}/nextclade' '$fasta'"
  run_cmd "pangolin '$fasta' --outdir '${out}/pangolin' --outfile '${sample}_lineage.csv'"
  mark_done "$done"; log "Lineage complete — $sample"
}

process_sample() {
  local sid="$1"; local bam; bam=$(get_bam "$sid")
  [[ -z "$bam" ]]   && error "Sample '$sid' not in metadata"
  [[ ! -f "${REPO_ROOT}/data/raw/$bam" ]] && error "BAM not found: data/raw/$bam"
  echo -e "\n${BOLD}${GREEN}════ Processing: $sid ════${NC}"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [START] $sid | $RUN_ID" >> "$AUDIT_LOG"
  IFS=',' read -ra MODS <<< "$MODULES"
  for mod in "${MODS[@]}"; do
    case "$mod" in
      qc)        module_qc        "$sid" "$bam" ;;
      align)     module_align     "$sid" "$bam" ;;
      variants)  module_variants  "$sid" ;;
      consensus) module_consensus "$sid" ;;
      lineage)   module_lineage   "$sid" ;;
      *)         warn "Unknown module: $mod" ;;
    esac
  done
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DONE] $sid" >> "$AUDIT_LOG"
  log "Sample $sid complete ✅"
}

run_cohort() {
  step "Cohort Analysis"
  local fastas=(); while IFS= read -r s; do
    local f="${RESULTS}/consensus/${s}/${s}.fasta"
    [[ -f "$f" ]] && fastas+=("$f")
  done < <(get_all_samples)
  [[ ${#fastas[@]} -lt 2 ]] && error "Need ≥2 consensus FASTAs. Found: ${#fastas[@]}"
  info "Found ${#fastas[@]} sequences"
  mkdir -p "${RESULTS}/phylogenetics"
  run_cmd "cat ${fastas[*]} '${REPO_ROOT}/data/reference/NC_045512.2.fasta' > '${RESULTS}/phylogenetics/all_sequences.fasta'"
  run_cmd "mafft --auto --thread 8 '${RESULTS}/phylogenetics/all_sequences.fasta' > '${RESULTS}/phylogenetics/all_aligned.fasta'"
  run_cmd "iqtree2 -s '${RESULTS}/phylogenetics/all_aligned.fasta' -m GTR+G -B 1000 -T AUTO --prefix '${RESULTS}/phylogenetics/sarscov2_ml_tree' --redo"
  run_cmd "multiqc '${RESULTS}/qc/fastqc' -o '${RESULTS}/qc/multiqc' --title 'SARS-CoV-2 Cohort QC' --force"
  log "Cohort analysis complete ✅"
}

echo -e "${BOLD}${CYAN}  SARS-CoV-2 Pipeline v${PIPELINE_VERSION} | Run: ${RUN_ID}${NC}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RUN] Pipeline started | $RUN_ID" >> "$AUDIT_LOG"

if   [[ "$RUN_COHORT" == true ]]; then run_cohort
elif [[ "$RUN_ALL"    == true ]]; then
  mapfile -t samples < <(get_all_samples)
  info "Processing ${#samples[@]} samples"
  for s in "${samples[@]}"; do process_sample "$s"; done
  info "All done. Run --cohort next."
elif [[ -n "$SAMPLE" ]]; then process_sample "$SAMPLE"
else echo -e "${RED}Specify --sample, --all, or --cohort${NC}"; show_help; exit 1
fi

log "Run $RUN_ID complete 🎉"
