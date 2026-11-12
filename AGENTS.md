# Project constraints

- Do not launch game clients, launchers, installers, graphical tests, or audio. The user is working on this machine. Compilation and explicitly headless checks only.
- Never assume a hidden window is equivalent to a headless test. Inspect upstream entry points before running anything from upstream.
- Never modify the KK platform installation or its game files.
- Never commit original game resources, executables, credentials, local paths, or generated resource manifests. Keep them in ignored directories.
- Use the engine revision required by OpenRA/ra2. Do not independently upgrade it.
- Preserve upstream license and attribution when incorporating source. No project-wide license is chosen yet.
- Record checks as passed only when actually executed. A resource hash is not evidence of authenticity or engine compatibility.

