# Setup Tutorial: Installing the Toolchain on Windows

This is a from-scratch, step-by-step guide for installing everything needed
to **write or modify** PROFI-5E programs for this project — written for
people with **no prior command-line or programming-tool experience**. It
assumes nothing is installed yet.

**Not sure you need this at all?** If you just want to burn the loader and
try the example programs as they are, you don't — the repository already
includes prebuilt `.bin` files for the loader and both examples, and that
path only needs Python (see README.md "Just want to use it?"). This guide
is for the next step: changing `loader.asm`, changing an example, or
writing your own program from scratch.

You'll install two things:

1. **Python** — runs the PC-side tools (`profi5e_build.py`, `profi5e_load.py`).
2. **The AS assembler (`asl`) and `p2bin`** — turn `.asm` source files into
   the `.bin` files the PROFI-5E actually runs. There are two ways to get
   these, covered as two options in Part 2 below:
   - **Option A — download prebuilt binaries** (faster, a couple of minutes).
   - **Option B — compile them from source** (slower, no `.exe` downloaded
     from a stranger to trust — everything is built on your own machine from
     source you can read).

Every "terminal" or "shell" below refers to a black window where you type
commands and press Enter — no code editor or IDE is needed for any of this.

---

## Part 1 — Install Python

1. Go to **[python.org/downloads](https://www.python.org/downloads/)** and
   download the latest Windows installer (the big yellow "Download Python"
   button already picks the right one).
2. Run the installer. **On the very first screen, tick the checkbox at the
   bottom that says "Add python.exe to PATH"** before clicking "Install Now".
   This step is easy to miss and is the #1 cause of "python not found" later.
3. When it finishes, open a fresh **Command Prompt**: press the Windows key,
   type `cmd`, press Enter.
4. Check it worked:
   ```
   py --version
   ```
   You should see something like `Python 3.12.x`. If you instead see an
   error, the PATH checkbox in step 2 was probably missed — rerun the
   installer and choose "Modify" → make sure "Add to PATH" is checked.
5. Install the one Python library this project needs:
   ```
   py -m pip install pyserial
   ```

Python is done. Keep this Command Prompt window around, or open a new one
whenever these instructions say "open a terminal".

---

## Part 2 — Install the assembler (asl / p2bin)

Pick **one** of the two options below, then continue to Part 3.

### Option A — Download prebuilt binaries (fastest)

This project's own [GitHub Releases page](https://github.com/miertink/profi5e/releases/tag/toolchain-win64-v1)
hosts a ready-to-use `asl.exe` + `p2bin.exe` for 64-bit Windows, compiled
from the same official assembler source used in Option B.

1. Download **`asl-p2bin-win64.zip`** from that release page.
2. **Windows will very likely show a blue "Windows protected your PC"
   SmartScreen screen** when you try to run either `.exe` for the first
   time. This happens because the files aren't signed with a paid code
   -signing certificate — it does **not** mean anything is wrong. Click
   "More info", then "Run anyway".
   - If you'd rather not take that on faith: the release page lists a
     SHA256 checksum for each file. Right-click the downloaded zip →
     properties, or run `certutil -hashfile asl.exe SHA256` in a Command
     Prompt, and compare against the published value.
   - Some antivirus products are also more suspicious of small, unsigned,
     rarely-downloaded `.exe` files in general (not specific to this one) —
     if yours quarantines it and you'd rather avoid that entirely, use
     Option B instead, which never downloads an executable at all.
3. Unzip it anywhere, e.g. `C:\tools\asl\bin` (create the folders if they
   don't exist). Keep `asl.exe` and `p2bin.exe` together in that folder.
4. Continue to **Part 3 — Add the assembler to your PATH**, using
   `C:\tools\asl\bin` (or wherever you unzipped it) as the folder to add.

### Option B — Compile from source

Slower, but nothing you run was downloaded as a pre-built `.exe` — only
source code, which the build step below turns into `asl.exe`/`p2bin.exe`
on your own machine.

#### Install MSYS2

MSYS2 provides a compiler (the program that turns human-readable source code
into a `.exe`) that isn't included in Windows by default. It's only needed
once, to build `asl`/`p2bin` — after that you won't touch MSYS2 again.

1. Go to **[msys2.org](https://www.msys2.org/)** and download the installer
   (the link near the top of the page).
2. Run it, accepting all the defaults (install location `C:\msys64`).
3. At the end of the installer, a terminal window opens automatically —
   **close it**, you don't need it yet.

MSYS2 installs several different terminal shortcuts in your Start Menu.
**This matters:** they are not interchangeable.

- Press the Windows key and type `MSYS2` to see them all.
- You need the one called **"MSYS2 MINGW64"** for every command below. Not
  "MSYS2 MSYS", not "MSYS2 UCRT64", not "MSYS2 CLANG64" — specifically
  **MINGW64**. Using the wrong one causes confusing "command not found"
  errors later.

Open **MSYS2 MINGW64** now and keep it open for the next part.

#### Install the compiler inside MSYS2

In the **MSYS2 MINGW64** window, run:

```
pacman -Syu
```

This updates MSYS2's own package database. It may finish by telling you to
**close the terminal window and reopen it** to continue — if so, do that
(reopen "MSYS2 MINGW64" again), then run the same command a second time
until it reports nothing left to do.

Then install the compiler, the build tool, and git (used to download the
assembler's source code):

```
pacman -S --needed mingw-w64-x86_64-gcc make git
```

Press Enter / type `y` if it asks for confirmation. This step downloads
roughly 200 MB and can take a few minutes.

#### Download and build the assembler

Still inside **MSYS2 MINGW64**, download the assembler's source code:

```
git clone https://github.com/Macroassembler-AS/asl-releases.git
cd asl-releases
git checkout upstream
```

Copy the build configuration written for exactly this setup (MSYS2 + MinGW):

```
cp Makefile.def-samples/Makefile.def-msys2-mingw Makefile.def
```

Open that file in a simple text editor to set where it gets installed:

```
nano Makefile.def
```

`nano` is a basic in-terminal text editor. Use the arrow keys to find the
last line, which reads:

```
INSTROOT:=C:/ASL
```

Change it to:

```
INSTROOT:=C:/tools/asl
```

(Any path is fine, as long as you remember it for Part 3 — `C:/tools/asl`
matches the rest of this guide.) Then save and exit nano: press `Ctrl+O`,
then `Enter` to confirm the filename, then `Ctrl+X` to exit.

Now build and install:

```
make
make install
```

`make` compiles the assembler (takes under a minute); `make install` copies
the finished `asl.exe` and `p2bin.exe` into `C:\tools\asl\bin`. If either
command prints errors instead of finishing cleanly, see Troubleshooting
below.

You're done with MSYS2 — the rest happens in a normal Windows Command
Prompt.

---

## Part 3 — Add the assembler to your PATH

(Whether you used Option A or Option B above, this step is the same.)

"PATH" is the list of folders Windows searches when you type a command name.
Right now, Windows doesn't know where `asl.exe` and `p2bin.exe` are, even
though they exist in `C:\tools\asl\bin`.

1. Press the Windows key, type `env`, and open **"Edit environment variables
   for your account"**.
2. In the top box ("User variables"), select the row named **Path**, click
   **Edit...**, then **New**.
3. Type `C:\tools\asl\bin` (or wherever you unzipped/installed it) and press
   Enter, then click **OK** on every open dialog.

This only takes effect in **new** terminal windows — any Command Prompt
already open needs to be closed and reopened.

---

## Part 4 — Verify everything

Open a **new** Command Prompt (Windows key → `cmd` → Enter) and run each of
these:

```
py --version
py -m pip show pyserial
asl
p2bin
```

- `py --version` should print a Python version.
- `pip show pyserial` should print package details (not "not found").
- `asl` and `p2bin` (with no arguments) should each print a short usage /
  version banner, not "is not recognized as an internal or external command".

If all four work, the toolchain is fully installed — continue with the
[Quickstart in README.md](../README.md#quickstart).

---

## Troubleshooting

- **`'asl' is not recognized...` / `'p2bin' is not recognized...`**
  The PATH change in Part 3 didn't take effect. Make sure you opened a
  *brand new* Command Prompt window after editing PATH (existing windows
  don't pick up the change). Double-check the folder you added in Part 3
  matches where `asl.exe`/`p2bin.exe` actually are, with a `\bin` at the
  end if that's how you organized it.

- **SmartScreen won't let me run the downloaded `.exe` at all (Option A)**
  Click "More info" on the blue warning screen — a "Run anyway" button
  appears only after that. If your antivirus deleted/quarantined the file
  instead, either restore it from quarantine or switch to Option B
  (compile from source), which never downloads an executable.

- **`gcc: command not found` / `make: command not found` inside MSYS2
  (Option B)**
  You're probably in the wrong MSYS2 terminal. Close it and reopen
  specifically **"MSYS2 MINGW64"** from the Start Menu — the compiler is
  only on that shell's PATH.

- **`make` fails partway through (Option B)**
  Confirm `Makefile.def` exists in the `asl-releases` folder (the `cp`
  command must have run without an error) and that the `INSTROOT` line
  uses forward slashes (`C:/tools/asl`, not `C:\tools\asl`).

- **`py` opens the Microsoft Store instead of running Python**
  Python wasn't actually installed, or PATH wasn't set — go back to Part 1
  and rerun the official installer from python.org, checking the "Add to
  PATH" box.
