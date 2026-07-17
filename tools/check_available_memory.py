#!/usr/bin/env python3
"""Fail browser/image batches when less than the protocol memory floor is free."""

from __future__ import annotations

import argparse
import ctypes
import platform
import time
from pathlib import Path


def available_bytes() -> int:
    if platform.system() == "Windows":
        class MemoryStatus(ctypes.Structure):
            _fields_ = [
                ("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong),
                ("ullTotalPhys", ctypes.c_ulonglong), ("ullAvailPhys", ctypes.c_ulonglong),
                ("ullTotalPageFile", ctypes.c_ulonglong), ("ullAvailPageFile", ctypes.c_ulonglong),
                ("ullTotalVirtual", ctypes.c_ulonglong), ("ullAvailVirtual", ctypes.c_ulonglong),
                ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
            ]
        status = MemoryStatus()
        status.dwLength = ctypes.sizeof(status)
        if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):
            raise OSError("GlobalMemoryStatusEx failed")
        return int(status.ullAvailPhys)
    meminfo = Path("/proc/meminfo").read_text(encoding="utf-8")
    for line in meminfo.splitlines():
        if line.startswith("MemAvailable:"):
            return int(line.split()[1]) * 1024
    raise OSError("MemAvailable is unavailable")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--min-mb", type=int, default=2048)
    parser.add_argument("--label", default="batch")
    parser.add_argument("--retry-seconds", type=int, default=60)
    parser.add_argument("--max-attempts", type=int, default=10)
    args = parser.parse_args()
    for attempt in range(1, max(1, args.max_attempts) + 1):
        available_mb = available_bytes() // 1048576
        print(f"R25_MEMORY_GATE label={args.label} attempt={attempt}/{args.max_attempts} available_mb={available_mb} required_mb={args.min_mb}", flush=True)
        if available_mb >= args.min_mb:
            return 0
        if attempt < args.max_attempts:
            print(f"R25_MEMORY_WAIT seconds={args.retry_seconds}", flush=True)
            time.sleep(max(1, args.retry_seconds))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
