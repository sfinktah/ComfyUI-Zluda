#!/usr/bin/env python3
import os
import sys
import subprocess
from datetime import datetime
from pathlib import Path

def now():
    n = datetime.now()
    return f"{int(n.strftime('%H')):2d}:{n.strftime('%M:%S')}"


def eprint(line=""):
    if line == "":
        sys.stderr.write("\n")
    else:
        sys.stderr.write(f" ::  {now()}  ::  {line}\n")

def show_gpu_architectures():
    eprint("")
    eprint("About TRITON_OVERRIDE_ARCH:")
    eprint("   This environment variable overrides Triton's automatic GPU architecture detection.")
    # The "Current value" is printed by the caller where appropriate
    eprint("")
    eprint("Common AMD GPU architectures:")
    eprint("  - RDNA 3 (RX 7000 series): gfx1100, gfx1101, gfx1102")
    eprint("  - RDNA 2 (RX 6000 series): gfx1030, gfx1031, gfx1032, gfx1033")
    eprint("  - RDNA 1 (RX 5000 series): gfx1010, gfx1011, gfx1012, gfx1013")
    eprint("  - GCN 5.1 (Vega 20): gfx906")
    eprint("  - GCN 5.0 (Vega 10/11): gfx900, gfx902")
    eprint("  - MI200 series: gfx90a")
    eprint("  - MI100 series: gfx908")

def show_windows_gui_instructions(mode):
    # mode: "edit" or "create"
    eprint("")
    eprint(f"To {mode} TRITON_OVERRIDE_ARCH in Windows using the GUI:")
    eprint('  1. Right-click "This PC" or "Computer" and select "Properties"')
    eprint('  2. Click "Advanced system settings" on the left side')
    eprint('  3. In the System Properties dialog, click "Environment Variables..."')
    if mode == "edit":
        eprint("  4. In the Environment Variables dialog:")
        eprint('     - For current user only: Look in "User variables" section')
        eprint('     - For all users: Look in "System variables" section')
        eprint('  5. Find "TRITON_OVERRIDE_ARCH" in the list and select it')
        eprint('  6. Click "Edit..." to modify the value')
        eprint("  7. Enter the new GPU architecture (e.g., gfx1100, gfx906, etc.)")
    else:
        eprint('  4. In the Environment Variables dialog, click "New..." under:')
        eprint('     - "User variables" (for current user only), or')
        eprint('     - "System variables" (for all users - requires admin rights)')
        eprint("  5. Enter:")
        eprint("     - Variable name: TRITON_OVERRIDE_ARCH")
        eprint("     - Variable value: your GPU architecture (e.g., gfx1100)")
    eprint('  6. Click "OK" three times to close all dialogs')
    eprint('  7. Restart your command prompt or application to use the new variable')
    eprint("")
    eprint("For temporary use in current session only:")
    eprint("  set TRITON_OVERRIDE_ARCH=your_gpu_architecture")
    eprint("")

def main():
    # If TRITON_OVERRIDE_ARCH is already defined
    existing = os.environ.get("TRITON_OVERRIDE_ARCH")
    if existing:
        eprint(f"- TRITON_OVERRIDE_ARCH is already defined: {existing}")
        eprint("- Skipping GPU architecture detection in favor of existing environment variable.")
        eprint("")
        eprint("About TRITON_OVERRIDE_ARCH:")
        eprint("   This environment variable overrides Triton's automatic GPU architecture detection.")
        eprint(f"   Current value: {existing}")
        # Detailed architecture info and Windows GUI edit instructions
        eprint("")
        eprint("Common AMD GPU architectures:")
        eprint("  - RDNA 3 (RX 7000 series): gfx1100, gfx1101, gfx1102")
        eprint("  - RDNA 2 (RX 6000 series): gfx1030, gfx1031, gfx1032, gfx1033")
        eprint("  - RDNA 1 (RX 5000 series): gfx1010, gfx1011, gfx1012, gfx1013")
        eprint("  - GCN 5.1 (Vega 20): gfx906")
        eprint("  - GCN 5.0 (Vega 10/11): gfx900, gfx902")
        eprint("  - MI200 series: gfx90a")
        eprint("  - MI100 series: gfx908")
        show_windows_gui_instructions("edit")
        print(existing)
        return 0

    # HIP_PATH check
    hip_path = os.environ.get("HIP_PATH")
    if not hip_path:
        eprint("- ERROR: HIP_PATH is not set or empty.")
        eprint("- This indicates that the HIP SDK was not properly installed.")
        eprint("     https://www.amd.com/en/developer/resources/rocm-hub/hip-sdk.html")
        eprint("- IMPORTANT: After installation, you must close and re-open")
        eprint("- all terminal/command prompt windows to refresh environment variables.")
        # Batch script also checks for ROCm folder presence on Windows
        program_files = os.environ.get("ProgramFiles")
        if program_files:
            rocm_path = Path(program_files) / "AMD" / "ROCm"
            if rocm_path.exists():
                eprint("- NOTE: ROCm installation detected, but HIP_PATH is not set.")
                eprint("- You may need to restart your terminal after HIP SDK installation.")
        return 1

    exe_name = "amdgpu-arch.exe" if os.name == "nt" else "amdgpu-arch"
    exe_path = Path(hip_path) / "bin" / exe_name

    # amdgpu-arch existence
    if not exe_path.exists():
        eprint(f"- ERROR: {exe_name} not found at {exe_path.parent}{os.sep}")
        eprint("- This indicates that the HIP SDK was not properly installed.")
        eprint("     https://www.amd.com/en/developer/resources/rocm-hub/hip-sdk.html")
        eprint("- IMPORTANT: After installation, you must close and re-open")
        eprint("- all terminal/command prompt windows to refresh environment variables.")
        eprint(f"- Current HIP_PATH: {hip_path}")
        return 1

    # Detect GPUs
    eprint("- Scanning for AMD GPU architectures...")
    try:
        proc = subprocess.run(
            [str(exe_path)],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            check=False,
        )
    except Exception as ex:
        eprint(f"- ERROR: Failed to run {exe_name}: {ex}")
        return 1

    gpus = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
    gpu_list_str = " ".join(gpus)
    eprint(f"- Detected {len(gpus)} AMD GPU architecture(s): {gpu_list_str}" if gpus else "- Detected 0 AMD GPU architecture(s):")

    # No GPUs found
    if len(gpus) < 1:
        eprint("- WARNING: Unable to detect AMD GPU architecture.")
        eprint("- This may indicate:")
        eprint("-   1. No AMD GPU is present in the system")
        eprint("-   2. GPU drivers are not properly installed")
        eprint("-   3. HIP SDK installation is incomplete")
        eprint("     https://www.amd.com/en/developer/resources/rocm-hub/hip-sdk.html")
        eprint("")
        eprint("MANUAL WORKAROUND - Set TRITON_OVERRIDE_ARCH manually:")
        eprint("  If you know your GPU architecture, you can manually set the TRITON_OVERRIDE_ARCH")
        eprint("  environment variable to bypass automatic detection.")
        # Show common architectures and Windows "create" instructions
        eprint("")
        eprint("Common AMD GPU architectures:")
        eprint("  - RDNA 3 (RX 7000 series): gfx1100, gfx1101, gfx1102")
        eprint("  - RDNA 2 (RX 6000 series): gfx1030, gfx1031, gfx1032, gfx1033")
        eprint("  - RDNA 1 (RX 5000 series): gfx1010, gfx1011, gfx1012, gfx1013")
        eprint("  - GCN 5.1 (Vega 20): gfx906")
        eprint("  - GCN 5.0 (Vega 10/11): gfx900, gfx902")
        eprint("  - MI200 series: gfx90a")
        eprint("  - MI100 series: gfx908")
        show_windows_gui_instructions("create")
        return 2

    # Single GPU
    if len(gpus) == 1:
        selected = gpus[0]
        eprint(f"- Single GPU detected: {selected}")
    else:
        # Multiple GPUs: verbose comparison
        eprint("- Multiple GPUs detected, selecting lexicographically highest...")
        best_idx = 1
        best_gpu = gpus[0]
        eprint(f"- Starting with GPU 1: {best_gpu}")
        for i in range(1, len(gpus)):
            current = gpus[i]
            eprint(f"- Comparing {current} with current best {best_gpu}")
            if current.lower() > best_gpu.lower():
                best_gpu = current
                best_idx = i + 1
                eprint(f"- New best: GPU {i+1} ({current})")
        selected = best_gpu

        if len(gpus) <= 4:
            summary = []
            for i, arch in enumerate(gpus, start=1):
                summary.append(f"[{arch}]" if i == best_idx else arch)
            eprint(f"- GPU architectures: {', '.join(summary)}")
        else:
            eprint(f"- Multiple GPU system ({len(gpus)} GPUs detected)")

        eprint(f"- Selected GPU {best_idx} (lexicographically highest): {selected}")

    # Export-like messages (to mimic batch behavior)
    eprint(f"- Exporting TRITON_OVERRIDE_ARCH={selected}")
    os.environ["TRITON_OVERRIDE_ARCH"] = selected

    # Print only the selected arch to stdout
    print(selected)
    return 0

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        eprint("- Aborted by user")
        raise SystemExit(130)