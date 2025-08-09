<div align="center">

# ComfyUI-ZLUDA

Windows-only version of ComfyUI which uses ZLUDA to get better performance with AMD GPUs.

</div>

## Table of Contents

- [What's New?](#whats-new)
- [Dependencies](#dependencies)
- [Setup (Windows-Only)](#setup-windows-only)
- [Troubleshooting](#troubleshooting)
- [Examples](#examples)
- [Credits](#credits)

*** FOR THOSE THAT ARE GETTING TROJAN DETECTIONS IN NCCL.DLL IN ZLUDA FOLDER, in dev's words :  "   nccl.dll is a dummy file, it does nothing. when one of its functions is called, it will just return "not supported" status. nccl.dll, cufftw.dll are dummy. they are introduced only for compatibility (to run applications that reject to start without them, but rarely or never use them).zluda.exe hijacks windows api and injects some dlls. its behavior can be considered as malicious by some antiviruses, but it does not hurt the user.
The antiviruses, including windows defender on my computer, didn't detect them as malicious when I made nightly build. but somehow the nightly build is now detected as virus on my end too.   " SO IGNORE THE WARNING AND MAYBE EXCLUDE THE ZLUDA FOLDER FROM DEFENDER.

 *** QUICK INSTALL INSTRUCTIONS : "https://github.com/patientx/ComfyUI-Zluda/issues/188"

## What's New?

* Python libs are copied automatically now, so triton compilation errors should be gone on startup. Also triton and torch patches are applied on install thanks to `https://github.com/sfinktah` 
* Updated included zluda version for the new install method to 3.9.5 nightly aka latest version available. You MUST use latest amd gpu drivers with this setup otherwise there would be problems later,  (drivers >= 25.5.1) """ WIPE THE CACHES , READ ON TROUBLESHOOTING BELOW """ I recommend using "patchzluda-n.bat" to install it , it uninstalls torch's and reinstalls and patches them with new zluda.ALSO you need to uninstall hip 6.2.4 completely, delete the folder , and reinstall it and again download and unzip the NEW Hip addon (this is not the same as the one I shared before , this is new for 3.9.5) for this 3.9.5 version (hopefully this won't happen that much) new hip addon for zluda 3.9.5 : (https://drive.google.com/file/d/1Gvg3hxNEj2Vsd2nQgwadrUEY6dYXy0H9/view?usp=sharing)
* Florance2 is now fixed , (probably some other nodes too) you need to disable "do_sample" meaning change it from True to False, now it would work without needing to edit it's node.
* To use any zluda you want (to use with HIP versions you want to use such as 6.1 - 6.2) After installing, close the app, run `patchzluda2.bat`. It will ask for url of the zluda build you want to use. You can choose from them here,
 [lshyqqtiger's ZLUDA Fork](https://github.com/lshqqytiger/ZLUDA/releases) then you can use `patchzluda2.bat`, run it paste the link via right click (A correct link would be like this, `https://github.com/lshqqytiger/ZLUDA/releases/download/rel.d60bddbc870827566b3d2d417e00e1d2d8acc026/ZLUDA-windows-rocm6-amd64.zip`)
 After pasting press enter and it would patch that zluda into comfy for you.

> [!IMPORTANT]
> 
> 📢 ***REGARDING KEEPING THE APP UP TO DATE***
>
> Avoid using the update function from the manager, instead use `git pull`, which we
> are doing on every start if `start.bat` is used. (App Already Does It Every Time You Open It, If You Are Using
> `comfyui.bat`, So This Way It Is Always Up To Date With Whatever Is On My GitHub Page)
>
> Only use comfy manager to update the extensions
> (Manager -> Custom Nodes Manager -> Set Filter To Installed -> Click Check Update On The Bottom Of The Window)
> otherwise it breaks the basic installation, and in that case run `install.bat` once again.
> 
> 📢 ***REGARDING RX 480-580 AND SIMILAR OLDER GPUS***
>
> Please use the "install-for-older-amd.bat" instead of "install.bat" or "install-n.bat" if you want to be able to use comfyui with zluda.

## Dependencies

* Do everything one by one, do not skip. *

1. **Git**: Download from https://git-scm.com/download/win.
   During installation don't forget to check the box for "Use Git from the Windows Command line and also from 3rd-party-software" to add Git to your system's PATH.
2. **Python** ([3.11.9](https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe)) version "3.11" . Install the latest release from python.org. Please don't use windows store version. If you have that installed, uninstall and please install from python.org. 
   During installation remember to check the box for "Add Python to PATH when you are at the "Customize Python" screen.
3. **Visual C++ Runtime**: Download [vc_redist.x64.exe](https://aka.ms/vs/17/release/vc_redist.x64.exe) and install it.
4. Install **HIP SDK 5.7.1** from [HERE](https://www.amd.com/en/developer/resources/rocm-hub/hip-sdk.html) the correct version, "Windows 10 & 11 5.7.1 HIP SDK"

   *** (*** this app installs zluda for 5.7.1 by default, if you want to use 6.1 or 6.2 you have to get the latest zluda link from
    [lshyqqtiger's ZLUDA Fork](https://github.com/lshqqytiger/ZLUDA/releases) then you can use `patchzluda2.bat`, run it paste the link via right click (a correct link would be like this, 
    `https://github.com/lshqqytiger/ZLUDA/releases/download/rel.d60bddbc870827566b3d2d417e00e1d2d8acc026/ZLUDA-windows-rocm6-amd64.zip` press enter and it would patch that zluda into comfy for you. Of course this also would mean you have to change the variables below 
     from "5.7" to "6.x" where needed) ***

5. Add the system variable HIP_PATH, value: `C:\Program Files\AMD\ROCm\5.7\` (This is the default folder with default 5.7.1 installed, if you
   have installed it on another drive, change if necessary, if you have installed 6.2.4, or other newer versions the numbers should reflect that.)
    1. Check the variables on the lower part (System Variables), there should be a variable called: HIP_PATH.
    2. Also check the variables on the lower part (System Variables), there should be a variable called: "Path".
       Double-click it and click "New" add this: `C:\Program Files\AMD\ROCm\5.7\bin` (This is the default folder with default 5.7.1 installed, if you
   have installed it on another drive, change if necessary, if you have installed 6.2.4, or other newer versions the numbers should reflect that.)

    ((( these should be  HIP_PATH, value: `C:\Program Files\AMD\ROCm\6.2\` and Path variable  `C:\Program Files\AMD\ROCm\6.2\bin` )))

   5.1  *** YOU MUST DO THIS ADDITIONAL STEPS : if you want to try miopen-triton with high end gpu : aka plan to use install-n.bat ***
   
    * You MUST use latest amd gpu drivers with this setup otherwise there would be problems later. (drivers >= 25.5.1)
    * You must install "https://visualstudio.microsoft.com/". Only "Build Tools" (aka Desktop Development with C++)  need to be selected and installed, we don't need the others.
    * Install **HIP SDK 6.2.4** from [HERE](https://www.amd.com/en/developer/resources/rocm-hub/hip-sdk.html) the correct version, "Windows 10 & 11 6.2.4 HIP SDK".
    * Then download hip sdk addon from this url and extract that into `C:\Program Files\AMD\ROCm\6.2` . (updated for zluda 3.9.5)
    *  (new hip addon for zluda 3.9.5 : (https://drive.google.com/file/d/1Gvg3hxNEj2Vsd2nQgwadrUEY6dYXy0H9/view?usp=sharing))
    *  (Alternative source for hip addon for zluda 3.9.5 : (https://www.mediafire.com/file/ooawc9s34sazerr/HIP-SDK-extension(zluda395).zip/file))
     
6. If you have an AMD GPU below 6800 (6700,6600 etc.), download the recommended library files for your gpu
   - !!! NOTE !!! : Besides those older gpu's the newest gfx1200 and gfx1201 aka 9070 - 9070xt STILL requires libraries because amd didn't add support for them in the 6.2.4 . In the future they %100 would but using 6.2.4 those gpu's also need libraries - from likelovewant libs. Those gpu's only have libraries for HIP 6.2.4, so you have to install HIP 6.2.4 and get the libraries from the likelovewant repository below for your gpu's. At this moment though, this newest GPU's have very poor performance with zluda even if you set them up with libraries etc ... Keep this in mind.

- from [Brknsoul Repository](https://github.com/brknsoul/ROCmLibs) (for hip 5.7.1)

- from [likelovewant Repository](https://github.com/likelovewant/ROCmLibs-for-gfx1103-AMD780M-APU/releases/tag/v0.6.2.4) (for hip 6.2.4)

    1. Go to folder "C:\Program Files\AMD\ROCm\5.7\bin\rocblas", (or 6.2 if you have installed that) there would be a "library" folder, backup the files
       inside to somewhere else.
    2. Open your downloaded optimized library archive and put them inside the library folder (overwriting if
       necessary): "C:\\Program Files\\AMD\\ROCm\\5.7\\bin\\rocblas\\library" (or 6.2 if you have installed that)
       * There could be a rocblas.dll file in the archive as well, if it is present then copy it inside "C:\Program Files\AMD\ROCm\5.7\bin\rocblas" (or 6.2 if you have installed that)
7. Reboot your system.

## Setup (Windows-Only)

Open a cmd prompt. (Powershell doesn't work, you have to use command prompt.)

```bash
git clone https://github.com/patientx/ComfyUI-Zluda
```

```bash
cd ComfyUI-Zluda
```

```bash
install.bat
```
((( use `install-n.bat` if you want to install for miopen-triton combo for high end gpu's )))

to start for later use (or create a shortcut to) :

```bash
comfyui.bat
```
((( use `comfyui-n.bat` if you want to use miopen-triton combo for high end gpu's, that basically changes the attention to pytorch attention which works with flash attention )))

    --- To use sage-attention , you have to change the "--use-pytorch-cross-attention" to "--use-sage-attention". My advice is make a seperate batch file for all different attention types instead of changing them.
    --- You can use "--use-pytorch-cross-attention", "--use-quad-cross-attention" , "--use-flash-attention" and "--use-sage-attention" . Also you can activate flash or sage with the help some nodes from pytorch attention.

also for later when you need to repatch zluda (maybe a torch update etc.) you can use:

```bash
patchzluda.bat
```

((( `patchzluda-n.bat` for miopen-triton setup)))

- The first generation would take around 10-15 minutes, there won't be any progress or indicator on the webui or cmd
  window, just wait. Zluda creates a database for use with generation with your gpu.

> [!NOTE]
> **This might happen with torch changes , zluda version changes and / or gpu driver changes.**

## Troubleshooting

- Use update.bat if comfyui.bat or comfyui-n.bat can't update. (as when they are the files that needs to be updated, so delete them, run update.bat) When you run your comfyui(-n).bat afterwards, it now copies correct zluda and uses that.
- WIPING CACHES FOR A CLEAN REINSTALL :: There are three caches to delete if you want to start anew -it is recommended if you want a painless zluda experience : 1-) "C:\Users\yourusername\AppData\Local\ZLUDA\ComputeCache" 2-) "C:\ Users \ yourusername \ .miopen" 3-) "C:\ Users \ yourusername \ .triton" , delete everything in these three directories, zluda and miopen and triton will do everything from the start again but it would be less painful for the future.
- Problems with triton , try this : Remove visual studio 2022 (if you have already installed it and getting errors) and install "https://aka.ms/vs/17/release/vs_BuildTools.exe" , and then use  "Developer Command Prompt" to run comfyui. This option shouldn't be needed for many but nevertheless try.
- `CUDA device detected: None` , if seeing this error with the new install-n , make sure you are NOT using the amd driver 25.5.1 . Use a previous driver, it has problems with zluda.
- `RuntimeError: CUDNN_BACKEND_OPERATIONGRAPH_DESCRIPTOR: cudnnFinalize FailedmiopenStatusInternalError cudnn_status: miopenStatusUnknownError` , if this is encountered at the end, while vae-decoding, use tiled-vae decoding either from official comfy nodes or from Tiled-Diffussion (my preference). Also vae-decoding is overall better with tiled-vae decoding. 
- DO NOT use non-english characters as folder names to put comfyui-zluda under.
- Wipe your pip cache "C:\Users\USERNAME\AppData\Local\pip\cache" You can also do this when venv is active with :  `pip cache purge`
- `xformers` isn't usable with zluda so any nodes / packages that require it doesn't work. `Flash attention`  doesn't work.
- Have the latest drivers installed for your amd gpu. **Also, Remove Any Nvidia Drivers** you might have from previous nvidia gpu's.
- If for some reason you can't solve with these and want to start from zero, delete "venv" folder and re-run  `install.bat`
- If you can't git pull to the latest version, run these commands, `git fetch --all` and then `git reset --hard origin/master` now you can git pull
- Problems with `caffe2_nvrtc.dll`: if you are sure you properly installed hip and can see it on path, please DON'T use python from windows store, use the link provided or 3.11 from the official website. After uninstalling python from
  windows store and installing the one from the website, be sure the delete venv folder, and run install.bat once again.
- `rocBLAS`-error: If you have an integrated GPU by AMD (e.g. AMD Radeon(TM) Graphics) you need to add `HIP_VISIBLE_DEVICES=1` to your environment variables. Other possible variables to use : `ROCR_VISIBLE_DEVICES=1` `HCC_AMDGPU_TARGET=1` . This basically tells it to use 1st gpu -this number could be different if you have multiple gpu's- otherwise it will default to using your iGPU, which will most likely not work. This behavior is caused by a bug in the ROCm-driver.
- Lots of other problems were encountered and solved by users so check the issues if you can't find your problem here.

## Examples

* A Wan 2.2 workflow that uses everything the new install method presents is uploaded. note: It is designed for 16 vram + 32 gb system ram, read the notes and probably something like 12gb vram maybe even 8gb vram (with low resolution and framecount) could be possible. BUT system ram becomes more important in those usecases. 
* There are some example workflows in cfz folder.
* Flux Guide [HERE](fluxguide.md)

## Credits

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI)
- [Zluda Wiki from SdNext](https://github.com/vladmandic/automatic/wiki/ZLUDA)
