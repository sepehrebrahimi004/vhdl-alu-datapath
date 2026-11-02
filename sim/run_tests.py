"""Compile and run every self-checking testbench.

    python sim/run_tests.py                       # uses xvhdl/xelab/xsim or ghdl from PATH
    python sim/run_tests.py --vivado C:/Xilinx/Vivado/2024.2/bin
    python sim/run_tests.py --vcd                 # also dump docs/*.vcd waveforms

Exit code 0 only if every testbench prints PASS.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "sim", "build")
RTL = ["multiplier16", "alu32", "seq_detector", "packet_checker", "datapath_top", "countdown_timer"]
TESTBENCHES = ["tb_multiplier16", "tb_alu32", "tb_seq_detector", "tb_packet_checker",
               "tb_datapath_top", "tb_countdown_timer"]
SOURCES = ([os.path.join(ROOT, "rtl", f + ".vhd") for f in RTL] +
           [os.path.join(ROOT, "tb", "tb_util.vhd")] +
           [os.path.join(ROOT, "tb", f + ".vhd") for f in TESTBENCHES])


def run(cmd):
    proc = subprocess.run(cmd, cwd=BUILD, capture_output=True, text=True, shell=(os.name == "nt"))
    return proc.returncode, proc.stdout + proc.stderr


def tool(bin_dir, name):
    if bin_dir:
        ext = ".bat" if os.name == "nt" else ""
        return os.path.join(bin_dir, name + ext)
    return shutil.which(name)


def xsim_flow(bin_dir, vcd):
    xvhdl, xelab, xsim = (tool(bin_dir, t) for t in ("xvhdl", "xelab", "xsim"))
    code, out = run([xvhdl, "--2008"] + SOURCES)
    if code != 0:
        print(out)
        raise SystemExit("compilation failed")
    results = {}
    for tb in TESTBENCHES:
        code, out = run([xelab, "--debug", "typical" if vcd else "off", tb, "-s", tb + "_sim"])
        if code != 0:
            print(out)
            results[tb] = "elaboration failed"
            continue
        args = [xsim, tb + "_sim"]
        if vcd:
            tcl = os.path.join(BUILD, tb + ".tcl")
            vcd_path = os.path.join(ROOT, "docs", tb + ".vcd").replace("\\", "/")
            with open(tcl, "w") as fh:
                fh.write(f"open_vcd {{{vcd_path}}}\nlog_vcd *\nrun all\nclose_vcd\nquit\n")
            args += ["-tclbatch", tcl.replace("\\", "/")]
        else:
            args += ["-R"]
        code, out = run(args)
        results[tb] = out
    return results


def ghdl_flow(vcd):
    ghdl = shutil.which("ghdl")
    for src in SOURCES:
        code, out = run([ghdl, "-a", "--std=08", src])
        if code != 0:
            print(out)
            raise SystemExit("compilation failed")
    results = {}
    for tb in TESTBENCHES:
        run([ghdl, "-e", "--std=08", tb])
        extra = [f"--vcd={os.path.join(ROOT, 'docs', tb + '.vcd')}"] if vcd else []
        results[tb] = run([ghdl, "-r", "--std=08", tb] + extra)[1]
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--vivado", help="Vivado bin directory (default: search PATH)")
    parser.add_argument("--vcd", action="store_true", help="dump waveforms to docs/")
    args = parser.parse_args()
    os.makedirs(BUILD, exist_ok=True)

    if args.vivado or shutil.which("xvhdl"):
        results = xsim_flow(args.vivado, args.vcd)
    elif shutil.which("ghdl"):
        results = ghdl_flow(args.vcd)
    else:
        raise SystemExit("No simulator found: install Vivado (XSim) or GHDL, or pass --vivado")

    failed = 0
    for tb, out in results.items():
        summary = re.findall(r"(?:PASS|FAIL) [^\n]*", out)
        problems = re.findall(r"CHECK FAILED[^\n]*", out)
        ok = summary and summary[-1].startswith("PASS") and not problems
        failed += not ok
        print(f"{'ok  ' if ok else 'FAIL'} {tb:22s} {summary[-1] if summary else out.strip()[-300:]}")
        for p in problems[:10]:
            print("      " + p)
    print(f"\n{len(results) - failed}/{len(results)} testbenches passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
