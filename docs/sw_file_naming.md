# Team file names

Start each project file with the team that owns it.

| Prefix | Team | Example |
|---|---|---|
| `sw_` | Software | `sw_network_probe.py`, `sw_main.c`, `sw_m1_team_review.md` |
| `hw_` | FPGA and digital hardware | `hw_modem.sv`, `hw_registers.vh` |
| `rf_` | RF design, measurements and calibration | `rf_calibration.py`, `rf_link_budget.md` |

Use lowercase words with underscores after the prefix. Tests start with `sw_test_`. SystemVerilog and Verilog source files use `hw_`. Files in an `rf/` directory use `rf_`, except Verilog source files, which use `hw_`.

These names stay as they are:

- `README.md`, `LICENSE` and `COPYING`, which are standard entry points.
- Git and GitHub metadata, such as `.gitignore` and the PR template.
- The five shared planning documents listed in `sw_check_file_names.py`.
- Unmodified third-party files and generated build outputs.

The tracked lwIP headers are `sw_lwipopts.h` and `arch/sw_cc.h`. The build copies them into an ignored configuration directory as `lwipopts.h` and `arch/cc.h`, which upstream lwIP requires.

Keep captures, logs, build records and one-off lab files under ignored `build/` or `.local/` directories.

Run the check after staging new files:

```bash
python3 tools/sw_check_file_names.py
```

Use Windows Python for a Windows-created worktree. Use Linux Python for a native Linux checkout. Git worktree paths can depend on the operating system that created them.

The same check runs on pushes and pull requests. It only reads tracked filenames. Software tests use the new prefix:

```bash
python3 -m unittest discover -s tests -p 'sw_test_*.py' -v
```
