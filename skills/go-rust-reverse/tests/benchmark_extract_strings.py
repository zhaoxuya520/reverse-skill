"""Measure count-mode time and memory for a chosen extractor and input file.

Run each implementation in a fresh process. Use --allocations separately from
timing runs because tracemalloc changes throughput. Peak RSS units are KiB on
Linux and bytes on macOS; RSS is omitted where the resource module is absent.
"""

import argparse
import contextlib
import importlib.util
import io
import json
import sys
import time
import tracemalloc

try:
    import resource
except ImportError:
    resource = None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("extractor", help="Path to extract_strings.py to measure")
    parser.add_argument("input", help="Binary fixture to count")
    parser.add_argument("--allocations", action="store_true")
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location("measured_extractor", args.extractor)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    sys.argv = [args.extractor, args.input, "count"]
    output = io.StringIO()
    if args.allocations:
        tracemalloc.start()
    start = time.perf_counter()
    with contextlib.redirect_stdout(output):
        code = module.main()
    seconds = time.perf_counter() - start
    peak = tracemalloc.get_traced_memory()[1] if args.allocations else None
    if args.allocations:
        tracemalloc.stop()
    print(json.dumps({
        "exit_code": code,
        "output": output.getvalue(),
        "seconds": seconds,
        "traced_peak_bytes": peak,
        "max_rss": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss if resource else None,
    }))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
