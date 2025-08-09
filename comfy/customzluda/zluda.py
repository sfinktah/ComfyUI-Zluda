# ------------------- Hide ROCm/HIP -------------------
import sys
import os

os.environ.pop("ROCM_HOME", None)
os.environ.pop("HIP_HOME", None)
os.environ.pop("ROCM_VERSION", None)

#triton fix?
os.environ["FLASH_ATTENTION_TRITON_AMD_ENABLE"] = "TRUE"
os.environ["FLASH_ATTENTION_TRITON_AMD_AUTOTUNE"] = "TRUE"
os.environ["TRITON_DEBUG"] = "1"     # Verbose logging

paths = os.environ["PATH"].split(";")
paths_no_rocm = [p for p in paths if "rocm" not in p.lower()]
os.environ["PATH"] = ";".join(paths_no_rocm)
# ------------------- End ROCm/HIP Hiding -------------

# Fix for cublasLt errors on newer ZLUDA (if no hipblaslt)
os.environ['DISABLE_ADDMM_CUDA_LT'] = '1'

# ------------------- main imports -------------------
# main imports
import torch

torch._dynamo.config.suppress_errors = True  # Skip compilation errors
torch._dynamo.config.optimize_ddp = False    # Disable distributed optimizations

import ctypes
import shutil
import subprocess
import importlib.metadata
from functools import wraps
from typing import Union, List
from enum import Enum
# ------------------- main imports -------------------

# ------------------- gfx detection -------------------
import os
import re

def detect_amd_gpu_architecture():
    """
    Detect AMD GPU architecture on Windows and return the appropriate gfx code for TRITON_OVERRIDE_ARCH
    """

    # Attempt to determine gfx code using amdgpu-arch.exe (preferred)
    hip_path_env_raw = os.environ.get("HIP_PATH")
    hip_path_env = hip_path_env_raw.strip().strip('"') if isinstance(hip_path_env_raw, str) else None

    # Resolve potential locations
    path_cmd = shutil.which("amdgpu-arch.exe")
    default_cmd = r"c:\Program Files\AMD\ROCm\6.2\bin\amdgpu-arch.exe"

    hip_root_exists = os.path.isdir(hip_path_env) if hip_path_env else False
    hip_bin_dir = os.path.join(hip_path_env, "bin") if hip_path_env else None
    hip_bin_exists = os.path.isdir(hip_bin_dir) if hip_bin_dir else False
    hip_cmd = os.path.join(hip_bin_dir, "amdgpu-arch.exe") if hip_bin_dir else None
    hip_cmd_exists = os.path.isfile(hip_cmd) if hip_cmd else False

    found_in_path = bool(path_cmd and os.path.isfile(path_cmd))
    found_in_hip = hip_cmd_exists
    found_in_default = os.path.isfile(default_cmd)

    used_cmd = path_cmd if found_in_path else (hip_cmd if found_in_hip else (default_cmd if found_in_default else None))

    # Validate HIP_PATH environment variable and provide actionable guidance
    if hip_path_env is None or hip_path_env == "":
        # HIP_PATH not set
        if found_in_path:
            # Case 4
            print("  ::  HIP_PATH is not set. Please create HIP_PATH (e.g., c:\\Program Files\\AMD\\ROCm\\6.2\\) and add %HIP_PATH%\\bin\\ to PATH.")
        else:
            # We'll handle full guidance below depending on discovery
            pass
    else:
        # HIP_PATH set; validate structure and contents
        if not hip_root_exists:
            print(f"  ::  HIP_PATH is set to '{hip_path_env}', but this directory does not exist. Please set HIP_PATH to your HIP SDK root (e.g., c:\\Program Files\\AMD\\ROCm\\6.2\\).")
        elif not hip_bin_exists:
            print(f"  ::  HIP_PATH is set to '{hip_path_env}', but '%HIP_PATH%\\bin\\' was not found. Please repair your HIP installation or correct HIP_PATH.")
        elif not hip_cmd_exists:
            print(f"  ::  HIP_PATH appears set, but 'amdgpu-arch.exe' was not found in '%HIP_PATH%\\bin\\'. Please verify your HIP SDK installation.")

    # Issue guidance per requirements (1-4)
    if used_cmd is None:
        # Case 1
        print("  ::  amdgpu-arch.exe not found in PATH, %HIP_PATH%\\bin, or default location.")
        print("  ::  Please install the AMD HIP SDK. After installation, set HIP_PATH to your HIP SDK root (e.g., c:\\Program Files\\AMD\\ROCm\\6.2\\) and add %HIP_PATH%\\bin\\ to your PATH.")
    else:
        if not found_in_path and found_in_hip:
            # Case 2
            print("  ::  amdgpu-arch.exe was not found in PATH, but located via %HIP_PATH%\\bin\\.")
            print("  ::  Please add %HIP_PATH%\\bin\\ to your Windows PATH:")
            print("      Settings -> System -> About -> Advanced system settings -> Environment Variables")
            print("      Under 'System variables', select 'Path' -> Edit -> New -> %HIP_PATH%\\bin\\ -> OK")
        if not found_in_path and not found_in_hip and found_in_default:
            # Case 3
            print("  ::  amdgpu-arch.exe was located via full path. Please define HIP_PATH and add %HIP_PATH%\\bin\\ to PATH.")
            print("      Example: set HIP_PATH=c:\\Program Files\\AMD\\ROCm\\6.2\\ then add %HIP_PATH%\\bin\\ to PATH.")
            print("      Windows: Settings -> System -> About -> Advanced system settings -> Environment Variables")
            print("      Create new system variable HIP_PATH with your HIP SDK root, then edit 'Path' to include %HIP_PATH%\\bin\\.")
        if found_in_path and (hip_path_env is None or hip_path_env == ""):
            # Case 4 (explicit)
            print("  ::  HIP_PATH is not set. Please create HIP_PATH (e.g., c:\\Program Files\\AMD\\ROCm\\6.2\\) and add %HIP_PATH%\\bin\\ to PATH.")
        # Additional hint if HIP_PATH is set but does not correctly contain the exe, even if command is in PATH
        if found_in_path and hip_path_env and (not hip_root_exists or not hip_bin_exists or not hip_cmd_exists):
            print("  ::  Note: HIP_PATH is set but does not point to a valid HIP SDK with amdgpu-arch.exe in %HIP_PATH%\\bin\\. Please correct HIP_PATH.")

        # Try to run amdgpu-arch.exe and parse output
        try:
            # Confirm the file exists just before execution
            if not os.path.isfile(used_cmd):
                print(f"  ::  Resolved amdgpu-arch.exe path does not exist: {used_cmd}. Falling back to other detection methods.")
            else:
                result = subprocess.run([used_cmd], capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    stdout_text = result.stdout or ""
                    lines = [ln.strip() for ln in stdout_text.splitlines() if ln.strip()]
                    if not lines:
                        print("  ::  amdgpu-arch.exe produced no output. Falling back to other detection methods.")
                    else:
                        print("  ::  amdgpu-arch.exe output:")
                        first_gfx = None
                        for ln in lines:
                            if ln.startswith("gfx"):
                                print(f"      - {ln}")
                                if first_gfx is None:
                                    first_gfx = ln
                            else:
                                print(f"      - {ln} ignored: unknown suffix")
                        if first_gfx:
                            return first_gfx
                        else:
                            print("  ::  No valid 'gfx' entries found in amdgpu-arch.exe output. Falling back to other detection methods.")
                else:
                    stderr_text = (result.stderr or "").strip()
                    err_msg = f"  ::  amdgpu-arch.exe exited with code {result.returncode}."
                    if stderr_text:
                        err_msg += f" Stderr: {stderr_text}"
                    print(err_msg + " Falling back to other detection methods.")
        except FileNotFoundError:
            # Shouldn't happen if used_cmd was resolved, but keep as safeguard
            print("  ::  amdgpu-arch.exe was not found at the resolved path during execution. Falling back to other detection methods.")
        except PermissionError:
            print("  ::  Permission denied when attempting to execute amdgpu-arch.exe. Try running as Administrator or correct file permissions.")
        except subprocess.TimeoutExpired:
            print("  ::  amdgpu-arch.exe timed out. Falling back to other detection methods.")
        except Exception as e:
            print(f"  ::  Failed to run amdgpu-arch.exe: {str(e)}")

    try:
        # Method 1: Try Windows registry
        try:
            import winreg
            key_path = r"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
            with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, key_path) as key:
                i = 0
                while True:
                    try:
                        subkey_name = winreg.EnumKey(key, i)
                        with winreg.OpenKey(key, subkey_name) as subkey:
                            try:
                                desc = winreg.QueryValueEx(subkey, "DriverDesc")[0]
                                if "AMD" in desc or "Radeon" in desc:
                                    print(f"  ::  Detected GPU via Windows registry: {desc}")
                                    return gpu_name_to_gfx(desc)
                            except FileNotFoundError:
                                pass
                        i += 1
                    except OSError:
                        break
        except ImportError:
            pass
        
        # Method 2: Try WMIC command
        try:
            import subprocess
            result = subprocess.run(['wmic', 'path', 'win32_VideoController', 'get', 'name'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    line = line.strip()
                    if line and "AMD" in line or "Radeon" in line:
                        print(f"  ::  Detected GPU via WMIC: {line}")
                        return gpu_name_to_gfx(line)
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass
        
        print("  ::  Could not detect AMD GPU architecture automatically")
        return None
        
    except Exception as e:
        print(f"  ::  GPU detection failed: {str(e)}")
        return None

import re

def gpu_name_to_gfx(gpu_name: str) -> str:
    """
    Map an AMD GPU product name to its corresponding GFX architecture code.
    Updated to include RDNA3.5 (gfx115x) and RDNA4 (gfx12xx) families.
    """

    name = gpu_name.lower().strip()

    # Mapping of GPU name substrings to GFX codes
    gpu_gfx_map = [
        # RDNA4 (gfx12xx, released/announced 2024+)
        (["rx 9900", "rx 9800", "rx 9700"],             "gfx1200"),  # RDNA4 (desktop/workstation)
        (["rx 9600", "rx 9500"],                        "gfx1201"),  # Entry-level RDNA4

        # RDNA3.5 (gfx115x, launched late 2023/2024)
        (["rx 8800"],                                   "gfx1150"),
        (["rx 8700", "8060s"],                          "gfx1151"),
        (["rx 8600"],                                   "gfx1152"),

        # RDNA3 (gfx11xx)
        (["pro w7900", "rx 7900"],                      "gfx1100"),
        (["pro w7800"],                                 "gfx1100"),
        (["pro w7700", "rx 7800", "rx 7700"],           "gfx1101"),
        (["rx 7600", "rx 7500"],                        "gfx1102"),

        # RDNA2 (gfx10xx)
        (["pro w6800", "rx 6950", "rx 6900", "rx 6800"], "gfx1030"),
        (["rx 6750", "rx 6700"],                         "gfx1031"),
        (["pro w6600", "rx 6650", "rx 6600", "rx 6500",
          "rx 6400"],                                    "gfx1032"),
        (["pro w6400"],                                  "gfx1034"),
        (["pro w6500"],                                  "gfx1035"),

        # RDNA1 (gfx101x)
        (["rx 5700", "rx 5600"],                         "gfx1010"),
        (["pro w5500", "rx 5500", "rx 5300"],            "gfx1012"),

        # Legacy architectures shown for completeness
        (["pro vii", "radeon vii"],                      "gfx906"),
        (["vega 64", "vega 56", "vega 20"],              "gfx906"),
        (["vega 11", "vega 8"],                          "gfx902"),
        (["rx 580", "rx 570", "rx 480", "rx 470"],       "gfx803"),
        (["rx 560", "rx 550", "rx 460"],                 "gfx803"),
    ]

    # First try for an exact match in lookup table
    for tokens, gfx_code in gpu_gfx_map:
        if any(token in name for token in tokens):
            return gfx_code

    # Heuristic mapping for known branding patterns
    # Attempt to parse "rx ####" and guess family
    match = re.search(r'(?:rx|radeon|pro)\s*(\d{4})', name)
    if match:
        number = int(match.group(1))
        if number >= 9900:
            return "gfx1200"   # Top RDNA4
        elif number >= 9700:
            return "gfx1200"   # RDNA4
        elif number >= 9600:
            return "gfx1201"   # RDNA4 entry/laptop
        elif number >= 8800:
            return "gfx1150"   # RDNA3.5
        elif number >= 8700:
            return "gfx1151"   # RDNA3.5 mid-range
        elif number >= 8600:
            return "gfx1152"   # RDNA3.5 low-end
        elif number >= 8000:
            return "gfx1151"   # The 8060S is gfx1151, and it's guess or fail.
        elif number >= 7900:
            return "gfx1100"
        elif number >= 7800:
            return "gfx1101"
        elif number >= 7600:
            return "gfx1102"
        elif number >= 7500:
            return "gfx1102"
        elif number >= 6950:
            return "gfx1030"
        elif number >= 6650:
            return "gfx1032"
        elif number >= 5700:
            return "gfx1010"

    print(f"  ::  Unknown GPU model: {gpu_name}, using default gfx1030")
    return 'gfx1030'  # Safe fallback for most modern AMD GPUs

def set_triton_arch_override():
    """
    Automatically detect and set TRITON_OVERRIDE_ARCH environment variable
    """
    # Check if already set by user
    if 'TRITON_OVERRIDE_ARCH' in os.environ:
        print(f"  ::  TRITON_OVERRIDE_ARCH already set to: {os.environ['TRITON_OVERRIDE_ARCH']}")
        gfx_arch = detect_amd_gpu_architecture()
        if gfx_arch != os.environ['TRITON_OVERRIDE_ARCH']:
            print(f"  ::  Warning: TRITON_OVERRIDE_ARCH does not match detected gfx_arch: {gfx_arch}")
        return
    
    print("  ::  Auto-detecting AMD GPU architecture for Triton...")
    gfx_arch = detect_amd_gpu_architecture()
    
    if gfx_arch:
        os.environ['TRITON_OVERRIDE_ARCH'] = gfx_arch
        print(f"  ::  Set TRITON_OVERRIDE_ARCH={gfx_arch}")
    else:
        # Fallback to a common architecture
        fallback_arch = 'gfx1030'
        os.environ['TRITON_OVERRIDE_ARCH'] = fallback_arch
        print(f"  ::  Using fallback TRITON_OVERRIDE_ARCH={fallback_arch}")
        print("  ::  If Triton fails, you may need to manually set TRITON_OVERRIDE_ARCH in your environment")
# ------------------- gfx detection -------------------

# ------------------- ComfyUI Package Version Check -------------------
def get_package_version(package_name):
    try:
        from importlib.metadata import version
        return version(package_name)
    except ImportError:
        from importlib_metadata import version
        return version(package_name)

def parse_requirements_file(requirements_path):
    """Parse requirements.txt file and extract package versions."""
    requirements = {}
    try:
        with open(requirements_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    # Handle different version specifiers
                    if '==' in line:
                        pkg, version = line.split('==', 1)
                        requirements[pkg] = version.strip()
                    elif '>=' in line:
                        pkg, version = line.split('>=', 1)
                        requirements[pkg] = version.strip()
                    elif '~=' in line:  # Compatible release operator
                        pkg, version = line.split('~=', 1)
                        requirements[pkg] = version.strip()
                    # You can add more operators if needed (>, <, <=, !=)
    except FileNotFoundError:
        print(f"  ::  Warning: requirements.txt not found at {requirements_path}")
    return requirements

def is_compatible_version(installed_version, required_version, operator='>='):
    """Check if installed version meets requirement based on operator."""
    try:
        from packaging import version
        installed_v = version.parse(installed_version)
        required_v = version.parse(required_version)
        
        if operator == '>=':
            return installed_v >= required_v
        elif operator == '==':
            return installed_v == required_v
        elif operator == '~=':
            # Compatible release: ~=2.0 means >=2.0, <3.0
            # ~=2.1 means >=2.1, <2.2
            required_parts = required_v.release
            if len(required_parts) == 1:
                # ~=2 means >=2.0, <3.0
                return (installed_v >= required_v and 
                        installed_v.release[0] == required_parts[0])
            else:
                # ~=2.1 means >=2.1, <2.2
                return (installed_v >= required_v and 
                        installed_v.release[:len(required_parts)-1] == required_parts[:-1] and
                        installed_v.release[len(required_parts)-1] >= required_parts[-1])
        else:
            # Default to >= for unknown operators
            return installed_v >= required_v
    except Exception as e:
        print(f"  ::  Version comparison error for {installed_version} vs {required_version}: {e}")
        return False

def uninstall_package(package_name):
    """Uninstall a package quietly"""
    import subprocess
    import sys
    try:
        args = [sys.executable, '-m', 'pip', 'uninstall', package_name, '-y', '--quiet']
        subprocess.check_call(args)
        return True
    except subprocess.CalledProcessError:
        return False

def check_pydantic_compatibility():
    """Check if current pydantic packages are compatible, return True if they need reinstalling"""
    try:
        # Try to import the problematic class that causes the error
        from pydantic_settings import TomlConfigSettingsSource
        # If we get here, the packages are compatible
        return False
    except ImportError:
        # Import failed, packages are incompatible
        return True
    except Exception:
        # Any other error, assume incompatible
        return True

def handle_pydantic_packages(required_packages):
    """Special handling for pydantic packages to ensure compatibility"""
    import subprocess
    import sys
    
    pydantic_packages = ['pydantic', 'pydantic-settings']
    packages_in_requirements = [pkg for pkg in pydantic_packages if pkg in required_packages]
    
    if not packages_in_requirements:
        return  # No pydantic packages to handle
    
    # Check if both packages are available and what versions
    pydantic_installed = None
    pydantic_settings_installed = None
    
    try:
        pydantic_installed = get_package_version('pydantic')
    except:
        pass
    
    try:
        pydantic_settings_installed = get_package_version('pydantic-settings')
    except:
        pass
    
    # If both are installed, check compatibility
    if pydantic_installed and pydantic_settings_installed:
        print(f"Found pydantic: {pydantic_installed}, pydantic-settings: {pydantic_settings_installed}")
        
        # Check if they're compatible by testing the import
        if not check_pydantic_compatibility():
            print("  ::  Pydantic packages are compatible, skipping reinstall")
            return
        else:
            print("  ::  Pydantic packages are incompatible, need to reinstall")
    
    # If we get here, we need to install/reinstall pydantic packages
    print("  ::  Setting up pydantic packages for compatibility...")
    
    # Uninstall existing versions to avoid conflicts
    if pydantic_installed:
        print(f"  ::  Uninstalling existing pydantic {pydantic_installed}")
        uninstall_package('pydantic')
    
    if pydantic_settings_installed:
        print(f"  ::  Uninstalling existing pydantic-settings {pydantic_settings_installed}")
        uninstall_package('pydantic-settings')
    
    # Install both packages together
    try:
        print("  ::  Installing compatible pydantic packages...")
        combined_args = [sys.executable, '-m', 'pip', 'install', 
                       'pydantic~=2.0', 
                       'pydantic-settings~=2.0',
                       '--quiet', 
                       '--disable-pip-version-check']
        
        subprocess.check_call(combined_args)
        
        # Verify installation
        new_pydantic = get_package_version('pydantic')
        new_pydantic_settings = get_package_version('pydantic-settings')
        print(f"  ::  Successfully installed pydantic: {new_pydantic}, pydantic-settings: {new_pydantic_settings}")
        
    except subprocess.CalledProcessError as e:
        print(f"  ::  Failed to install pydantic packages: {e}")

def install_package(package_name, version_spec, upgrade=False):
    import subprocess
    import sys
    
    # For ~= operator, install with the compatible release syntax
    if '~=' in version_spec:
        package_spec = f'{package_name}~={version_spec}'
    else:
        package_spec = f'{package_name}=={version_spec}'
    
    args = [sys.executable, '-m', 'pip', 'install', 
            package_spec, 
            '--quiet', 
            '--disable-pip-version-check']
    if upgrade:
        args.append('--upgrade')
    
    try:
        subprocess.check_call(args)
    except subprocess.CalledProcessError as e:
        print(f"  ::  Failed to install {package_name}: {e}")
        # Try installing without version constraint as fallback
        if upgrade and '~=' in package_spec:
            try:
                print(f"  ::  Retrying {package_name} installation without version constraint...")
                fallback_args = [sys.executable, '-m', 'pip', 'install', 
                               package_name, 
                               '--upgrade',
                               '--quiet', 
                               '--disable-pip-version-check']
                subprocess.check_call(fallback_args)
                print(f"  ::  {package_name} installed successfully without version constraint")
            except subprocess.CalledProcessError as e2:
                print(f"  ::  Fallback installation also failed: {e2}")

def ensure_package(package_name, required_version, operator='>='):
    # Skip individual pydantic package handling - they're handled together
    if package_name in ['pydantic', 'pydantic-settings']:
        return
        
    try:
        installed_version = get_package_version(package_name)
        print(f"Installed version of {package_name}: {installed_version}")
        
        if not is_compatible_version(installed_version, required_version, operator):
            install_package(package_name, required_version, upgrade=True)
            print(f"\n{package_name} outdated. Upgraded to {required_version}.")
    except Exception as e:
        print(f"  ::  {package_name} not found or error checking version: {e}")
        install_package(package_name, required_version)
        print(f"\n{package_name} was missing. Installed it.")

# Determine operator from requirements.txt
def get_version_operator(requirements_path, package_name):
    """Extract the version operator used for a package in requirements.txt"""
    try:
        with open(requirements_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and line.startswith(package_name):
                    if '~=' in line:
                        return '~='
                    elif '==' in line:
                        return '=='
                    elif '>=' in line:
                        return '>='
    except FileNotFoundError:
        pass
    return '>='  # Default

import os
requirements_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'requirements.txt')
required_packages = parse_requirements_file(requirements_path)

packages_to_monitor = [
    "comfyui-frontend-package",
    "comfyui-workflow-templates",
    "av",
    "comfyui-embedded-docs",
    "pydantic",
    "pydantic-settings",
]

print("\n  ::  Checking package versions...")

# Handle pydantic packages first with special logic
handle_pydantic_packages(required_packages)

# Handle other packages
for package_name in packages_to_monitor:
    if package_name in required_packages and package_name not in ['pydantic', 'pydantic-settings']:
        operator = get_version_operator(requirements_path, package_name)
        ensure_package(package_name, required_packages[package_name], operator)
    elif package_name not in ['pydantic', 'pydantic-settings']:
        print(f"  ::  Warning: {package_name} not found in requirements.txt")

print("  ::  Package version check complete.")
# ------------------- End Version Check -------------------

# ------------------- Triton Setup -------------------
print("\n  ::  ------------------------ ZLUDA -----------------------  ::  ")

# identify device and set triton arch override
zluda_device_name = torch.cuda.get_device_name() if torch.cuda.is_available() else ""
is_zluda = zluda_device_name.endswith("[ZLUDA]")
if is_zluda:
    set_triton_arch_override()

try:
    import triton
    import triton.language as tl
    print("  ::  Triton core imported successfully")
    
    @triton.jit
    def _zluda_kernel_test(x_ptr, y_ptr, n_elements, BLOCK_SIZE: tl.constexpr):
        pid = tl.program_id(axis=0)
        offsets = pid * BLOCK_SIZE + tl.arange(0, BLOCK_SIZE)
        mask = offsets < n_elements
        x = tl.load(x_ptr + offsets, mask=mask)
        tl.store(y_ptr + offsets, x + 1, mask=mask)
    
    def _verify_triton() -> bool:
        try:
            print("  ::  Running Triton kernel test...")
            x = torch.ones(64, device='cuda')
            y = torch.empty_like(x)
            _zluda_kernel_test[(1,)](x, y, x.numel(), BLOCK_SIZE=64)
            if torch.allclose(y, x + 1):
                print("  ::  Triton kernel test passed successfully")
                return True
            print("  ::  Triton kernel test failed (incorrect output)")
            return False
        except Exception as e:
            print(f"  ::  Triton test failed: {str(e)}")
            return False
    
    triton_available = _verify_triton()
    if triton_available:
        print("  ::  Triton initialized successfully")
        os.environ['FLASH_ATTENTION_TRITON_AMD_AUTOTUNE'] = 'TRUE'
    else:
        print("  ::  Triton available but failed verification")

except ImportError:
    print("  ::  Triton not installed")
    triton_available = False
except Exception as e:
    print(f"  ::  Triton initialization failed: {str(e)}")
    triton_available = False
# ------------------- End Triton Verification -------------------

# # ------------------- ZLUDA Core Implementation -------------------
MEM_BUS_WIDTH = {
    "AMD Radeon RX 9070 XT": 256,
    "AMD Radeon RX 9070": 256,
    "AMD Radeon RX 9060 XT": 192,
    "AMD Radeon RX 7900 XTX": 384,
    "AMD Radeon RX 7900 XT": 320,
    "AMD Radeon RX 7900 GRE": 256,
    "AMD Radeon RX 7800 XT": 256,
    "AMD Radeon RX 7700 XT": 192,
    "AMD Radeon RX 7700": 192,
    "AMD Radeon RX 7650 GRE": 128,
    "AMD Radeon RX 7600 XT": 128,
    "AMD Radeon RX 7600": 128,
    "AMD Radeon RX 7500 XT": 96,
    "AMD Radeon RX 6950 XT": 256,
    "AMD Radeon RX 6900 XT": 256,
    "AMD Radeon RX 6800 XT": 256,
    "AMD Radeon RX 6800": 256,
    "AMD Radeon RX 6750 XT": 192,
    "AMD Radeon RX 6700 XT": 192,
    "AMD Radeon RX 6700": 160,
    "AMD Radeon RX 6650 XT": 128,
    "AMD Radeon RX 6600 XT": 128,
    "AMD Radeon RX 6600": 128,
    "AMD Radeon RX 6500 XT": 64,
    "AMD Radeon RX 6400": 64,
}

# ------------------- Device Properties Implementation -------------------
class DeviceProperties:
    PROPERTIES_OVERRIDE = {"regs_per_multiprocessor": 65535, "gcnArchName": "UNKNOWN ARCHITECTURE"}
    internal: torch._C._CudaDeviceProperties

    def __init__(self, props: torch._C._CudaDeviceProperties):
        self.internal = props

    def __getattr__(self, name):
        if name in DeviceProperties.PROPERTIES_OVERRIDE:
            return DeviceProperties.PROPERTIES_OVERRIDE[name]
        return getattr(self.internal, name)

# # ------------------- Audio Ops Patch -------------------
# if is_zluda:
    # _torch_stft = torch.stft
    # _torch_istft = torch.istft

    # def z_stft(input: torch.Tensor, window: torch.Tensor, *args, **kwargs):
        # return _torch_stft(input=input.cpu(), window=window.cpu(), *args, **kwargs).to(input.device)

    # def z_istft(input: torch.Tensor, window: torch.Tensor, *args, **kwargs):
        # return _torch_istft(input=input.cpu(), window=window.cpu(), *args, **kwargs).to(input.device)

    # def z_jit(f, *_, **__):
        # f.graph = torch._C.Graph()
        # return f

    # torch._dynamo.config.suppress_errors = True
    # torch.stft = z_stft
    # torch.istft = z_istft
    # torch.jit.script = z_jit
# # ------------------- End Audio Patch ------------------- 

# ------------------- Top-K Fallback Patch -------------------
if is_zluda:
    _topk = torch.topk

    def safe_topk(input: torch.Tensor, *args, **kwargs):
        device = input.device
        values, indices = _topk(input.cpu(), *args, **kwargs)
        return torch.return_types.topk((values.to(device), indices.to(device),))

    torch.topk = safe_topk
# ------------------- End Top-K Patch -------------------

# ------------------- ONNX Runtime Patch -------------------
try:
    import onnxruntime as ort

    if is_zluda:
        print("  ::  Patching ONNX Runtime for ZLUDA — disabling CUDA EP.")

        # Store original get_available_providers
        original_get_available_providers = ort.get_available_providers

        def filtered_providers():
            return [ep for ep in original_get_available_providers() if ep != "CUDAExecutionProvider"]

        # Patch ONLY the _pybind_state version (used during session creation)
        ort.capi._pybind_state.get_available_providers = filtered_providers

        # Wrap InferenceSession to force CPU provider when CUDA is explicitly requested
        OriginalSession = ort.InferenceSession

        class SafeInferenceSession(OriginalSession):
            def __init__(self, *args, providers=None, **kwargs):
                if providers and "CUDAExecutionProvider" in providers:
                    print("  ::  Forcing ONNX to use CPUExecutionProvider instead of CUDA.")
                    providers = ["CPUExecutionProvider"]
                super().__init__(*args, providers=providers, **kwargs)

        ort.InferenceSession = SafeInferenceSession
except ImportError:
    print("  ::  ONNX Runtime not installed — skipping patch.")
except Exception as e:
    print("  ::  Failed to patch ONNX Runtime:", e)
# ------------------- End ONNX Patch -------------------

# ------------------- ZLUDA hijack ---------------------
do_nothing = lambda _: None
def do_hijack():
    if not is_zluda:
        return
    print(f"  ::  Using ZLUDA with device: {zluda_device_name}")
    print("  ::  Applying core ZLUDA patches...")
    
    # 2. Triton optimizations
    if triton_available:
        print("  ::  Initializing Triton optimizations")
        try:
            # General Triton config
            print("  ::  Configuring Triton device properties...")
            _get_props = triton.runtime.driver.active.utils.get_device_properties
            def patched_props(device):
                props = _get_props(device)
                name = torch.cuda.get_device_name()[:-8]  # Remove [ZLUDA]
                props["mem_bus_width"] = MEM_BUS_WIDTH.get(name, 128)
                if name not in MEM_BUS_WIDTH:
                    print(f'  ::  Using default mem_bus_width=128 for {name}')
                return props
            triton.runtime.driver.active.utils.get_device_properties = patched_props
            print("  ::  Triton device properties configured")

            # Flash Attention
            flash_enabled = False
            try:
                from comfy.flash_attn_triton_amd import interface_fa
                print("  ::  Flash attention components found")
                
                original_sdpa = torch.nn.functional.scaled_dot_product_attention
                
                def amd_flash_wrapper(query, key, value, attn_mask=None, dropout_p=0.0, is_causal=False, scale=None):
                    try:
                        if (query.shape[-1] <= 128 and 
                            attn_mask is None and # fix flash-attention error : "Flash attention error: Boolean value of Tensor with more than one value is ambiguous" 
                            query.dtype != torch.float32):
                            if scale is None:
                                scale = query.shape[-1] ** -0.5
                            return interface_fa.fwd(
                                query.transpose(1, 2),
                                key.transpose(1, 2),
                                value.transpose(1, 2),
                                None, None, dropout_p, scale,
                                is_causal, -1, -1, 0.0, False, None
                            )[0].transpose(1, 2)
                    except Exception as e:
                        print(f'  ::  Flash attention error: {str(e)}')
                    return original_sdpa(query=query, key=key, value=value, attn_mask=attn_mask, dropout_p=dropout_p, is_causal=is_causal, scale=scale)
                
                torch.nn.functional.scaled_dot_product_attention = amd_flash_wrapper
                flash_enabled = True
                print("  ::  AMD flash attention enabled successfully")
                
            except ImportError:
                print("  ::  Flash attention components not installed")
            except Exception as e:
                print(f"  ::  Flash attention setup failed: {str(e)}")

            # Other Triton optimizations
            if not flash_enabled:
                print("  ::  Applying basic Triton optimizations")
                # Add other Triton optimizations here
                # ...

        except Exception as e:
            print(f"  ::  Triton optimization failed: {str(e)}")
    else:
        print("  ::  Triton optimizations skipped (not available)")

    # 3. Common configurations
    print("  ::  Configuring PyTorch backends...")
    torch.backends.cuda.enable_mem_efficient_sdp(False)
    torch.backends.cuda.enable_mem_efficient_sdp = do_nothing
    torch.backends.cudnn.enabled = True
    if hasattr(torch.backends.cuda, "enable_flash_sdp"):
        torch.backends.cuda.enable_flash_sdp(True)
        print("  ::  Disabled CUDA flash attention")
    if hasattr(torch.backends.cuda, "enable_math_sdp"):
        torch.backends.cuda.enable_math_sdp(True)
        print("  ::  Enabled math attention fallback")

    print("  ::  ZLUDA initialization complete")
    print("  ::  ------------------------ ZLUDA -----------------------  ::  \n")

if is_zluda:
    do_hijack()
else:
    print(f"  ::  CUDA device detected: {zluda_device_name or 'None'}")
