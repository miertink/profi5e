# Setup Tutorial: Installing the Toolchain on Windows

This is a from-scratch, step-by-step guide for installing everything needed
to build and use this project — written for people with **no prior
command-line or programming-tool experience**. It assumes nothing is
installed yet.

You'll install two things:

1. **Python** — runs the PC-side tools (`profi5e_build.py`, `profi5e_load.py`).
2. **The AS assembler (`asl`) and `p2bin`** — turn `.asm` source files into
   the `.bin` files the PROFI-5E actually runs. These aren't available as a
   simple installer, so this guide compiles them from source using a small,
   free Unix-like environment for Windows called **MSYS2**. That sounds more
   intimidating than it is — it's mostly copy-pasting a handful of commands.

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

## Part 2 — Install MSYS2

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

Open **MSYS2 MINGW64** now and keep it open for the next parts.

---

## Part 3 — Install the compiler inside MSYS2

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

---

## Part 4 — Download and build the assembler

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

(Any path is fine, as long as you remember it for Part 5 — `C:/tools/asl`
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

## Part 5 — Add the assembler to your PATH

"PATH" is the list of folders Windows searches when you type a command name.
Right now, Windows doesn't know where `asl.exe` and `p2bin.exe` are, even
though they exist in `C:\tools\asl\bin`.

1. Press the Windows key, type `env`, and open **"Edit environment variables
   for your account"**.
2. In the top box ("User variables"), select the row named **Path**, click
   **Edit...**, then **New**.
3. Type `C:\tools\asl\bin` (or whatever path you set in Part 4) and press
   Enter, then click **OK** on every open dialog.

This only takes effect in **new** terminal windows — any Command Prompt
already open needs to be closed and reopened.

---

## Part 6 — Verify everything

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
  The PATH change in Part 5 didn't take effect. Make sure you opened a
  *brand new* Command Prompt window after editing PATH (existing windows
  don't pick up the change). Double-check the folder in Part 5 matches
  `INSTROOT` from Part 4 exactly, with a `\bin` at the end.

- **`gcc: command not found` / `make: command not found` inside MSYS2**
  You're probably in the wrong MSYS2 terminal. Close it and reopen
  specifically **"MSYS2 MINGW64"** from the Start Menu (see Part 2) — the
  compiler installed in Part 3 is only on that shell's PATH.

- **`make` fails partway through**
  Confirm `Makefile.def` exists in the `asl-releases` folder (the `cp`
  command in Part 4 must have run without an error) and that the `INSTROOT`
  line uses forward slashes (`C:/tools/asl`, not `C:\tools\asl`).

- **`py` opens the Microsoft Store instead of running Python**
  Python wasn't actually installed, or PATH wasn't set — go back to Part 1
  and rerun the official installer from python.org, checking the "Add to
  PATH" box.
