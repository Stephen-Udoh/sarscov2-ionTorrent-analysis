"""
Pipeline audit logger.
Usage:
    from utils.logger import PipelineLogger
    logger = PipelineLogger(sample_id="IonCode_0108", module="qc")
    logger.info("FastQC complete")
    logger.log_metric("total_reads", 245000)
    logger.qc_gate("reads", 245000, threshold_pass=10000, status="PASS")
"""

import logging
import json
import sys
import subprocess
from pathlib import Path
from datetime import datetime
from typing import Any, Optional


class PipelineLogger:
    COLOURS = {
        "INFO":  "\033[0;32m",
        "WARN":  "\033[1;33m",
        "ERROR": "\033[0;31m",
        "DEBUG": "\033[0;34m",
        "RESET": "\033[0m",
    }

    def __init__(self, sample_id=None, module=None, repo_root=None, verbose=True):
        self.sample_id = sample_id or "cohort"
        self.module    = module    or "pipeline"
        self.repo_root = Path(repo_root) if repo_root else Path.cwd()
        self.verbose   = verbose
        self.metrics   = {}
        self.qc_results = {}

        self.audit_log_path = self.repo_root / "audit.log"
        log_dir = self.repo_root / "results" / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        self.sample_log_path = log_dir / f"{self.sample_id}_{self.module}.log"
        self._setup_logging()

    def _setup_logging(self):
        self.logger = logging.getLogger(f"{self.sample_id}.{self.module}")
        self.logger.setLevel(logging.DEBUG)
        self.logger.handlers.clear()
        fh = logging.FileHandler(self.sample_log_path, mode="a")
        fh.setFormatter(logging.Formatter(
            "%(asctime)s | %(levelname)-8s | %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"))
        self.logger.addHandler(fh)

    def _console(self, level, message):
        if not self.verbose:
            return
        c = self.COLOURS.get(level, "")
        r = self.COLOURS["RESET"]
        ts = datetime.now().strftime("%H:%M:%S")
        icons = {"INFO": "✅", "WARN": "⚠️ ", "ERROR": "❌", "DEBUG": "🔍"}
        print(f"{c}[{ts}] {icons.get(level,'')} [{self.sample_id}] {message}{r}", flush=True)

    def _audit(self, level, message, extra=None):
        record = {"timestamp": datetime.now().isoformat(),
                  "level": level, "sample": self.sample_id,
                  "module": self.module, "message": message}
        if extra:
            record.update(extra)
        with open(self.audit_log_path, "a") as f:
            f.write(json.dumps(record) + "\n")

    def info(self, message):
        self._console("INFO", message); self.logger.info(message); self._audit("INFO", message)

    def warn(self, message):
        self._console("WARN", message); self.logger.warning(message); self._audit("WARN", message)

    def error(self, message, exit_code=1):
        self._console("ERROR", message); self.logger.error(message)
        self._audit("ERROR", message); sys.exit(exit_code)

    def log_command(self, command):
        self.logger.debug(f"CMD: {command}"); self._audit("CMD", command)

    def log_metric(self, name, value, unit=""):
        self.metrics[name] = value
        msg = f"METRIC | {name}: {value}{' ' + unit if unit else ''}"
        self.info(msg); self._audit("METRIC", msg, {"metric": name, "value": value})

    def qc_gate(self, metric_name, observed_value, threshold_pass,
                threshold_flag=None, higher_is_better=True):
        if higher_is_better:
            if observed_value >= threshold_pass:                          status = "PASS"
            elif threshold_flag and observed_value >= threshold_flag:     status = "FLAG"
            else:                                                         status = "FAIL"
        else:
            if observed_value <= threshold_pass:                          status = "PASS"
            elif threshold_flag and observed_value <= threshold_flag:     status = "FLAG"
            else:                                                         status = "FAIL"
        self.qc_results[metric_name] = status
        icons = {"PASS": "✅", "FLAG": "⚠️ ", "FAIL": "❌"}
        msg = f"QC GATE | {metric_name}: {observed_value} (threshold={threshold_pass}) → {icons[status]} {status}"
        level = "INFO" if status == "PASS" else ("WARN" if status == "FLAG" else "ERROR")
        self._console(level, msg); self.logger.info(msg)
        self._audit(f"QC_{status}", msg, {"metric": metric_name, "observed": observed_value, "status": status})
        return status

    def run_command(self, cmd, check=True):
        self.log_command(cmd)
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode != 0 and check:
            self.error(f"Command failed: {cmd}\n{result.stderr}")
        return result

    def summary(self):
        return {"sample_id": self.sample_id, "module": self.module,
                "timestamp": datetime.now().isoformat(),
                "metrics": self.metrics, "qc_results": self.qc_results,
                "overall_status": "FAIL" if "FAIL" in self.qc_results.values()
                                  else "FLAG" if "FLAG" in self.qc_results.values() else "PASS"}
