# ITNOW

ITNOW is a MATLAB pipeline for nowcasting Italian nominal GDP growth from
monthly and quarterly macroeconomic indicators.

The project is organized around three stages:

1. `GetData.m` downloads and transforms the current data vintage.
2. `GetHistFcast.m` runs the historical nowcast model set and combinations.
3. `scripts/build_current_nowcast.py` builds the public website figures,
   summary tables, and history-row payload from the forecast outputs.

The automated entry point is:

```matlab
setup_itnow; RunITNOWUpdate
```

From the terminal, launch the full pipeline with:

```bash
matlab -batch "setup_itnow; RunITNOWUpdate"
```

For a first test that does not write into the website repository, run:

```bash
matlab -batch "setup_itnow; RunITNOWUpdate('update_website', false)"
```

If ISTAT edition discovery is slow or unavailable, bypass it with known
editions:

```bash
matlab -batch "setup_itnow; RunITNOWUpdate('update_website', false, 'edition', '2026M5', 'preliminary_ed', '2026M4')"
```

Unless an `eval_end` override is supplied, this command uses the first day of
the previous completed calendar month. For example, on 16 June 2026 it uses
`Eval_End = 2026-05-01`.

The full run downloads data, runs the historical forecast models, builds the
current nowcast figures and tables, and, unless disabled, stages the website
files in the configured `andreaviselli.github.io` checkout. The orchestrator
prints five numbered stages with timestamps and elapsed times, starting with a
preflight check.

For non-quarter-end updates, such as an `Eval_End` in May, website staging
updates the monthly growth chart/table and history workbook only. The
reference-quarter section and level chart are refreshed only for March, June,
September, and December evaluation ends.

If forecasts already exist and only website staging is missing, do not rerun
the full pipeline. Stage the website from existing outputs with:

```bash
matlab -batch "setup_itnow; DeployITNOWWebsite"
```

or choose a specific vintage:

```bash
matlab -batch "setup_itnow; DeployITNOWWebsite('vintage', '20260509')"
```

By default, the automated run:

- uses the project root as `base_path`;
- chooses `Eval_End` as the first day of the previous completed month;
- probes ISTAT GDP endpoints for the newest usable final and preliminary
  editions;
- attempts the STOOQ FTSE MIB CSV download before failing fast in
  non-interactive mode unless a valid cached `DATA/FTSEMIB.csv` fallback is
  available;
- writes data and history outputs under the gitignored `DATA/` and
  `HISTORY/` folders;
- stages website artifacts to the configured `andreaviselli.github.io`
  checkout when website updating is enabled.

For architecture and operating details, see [PIPELINE.md](PIPELINE.md).

## What Remains

The current automation layer is launchable and has been exercised against the
20260616 output vintage, including website staging from existing forecast
outputs.

Remaining work:

- If STOOQ blocks the automatic FTSE MIB download, switch that helper to
  `stooq_then_manual` or manually download the CSV, rename it to
  `FTSEMIB.csv`, and place it at `DATA/FTSEMIB.csv`.
- Add a remote scheduler, such as GitHub Actions or a self-hosted runner with
  MATLAB access, for updates while the local computer is offline.
- Add stronger publication validation before automatic publication, especially
  checks that the final nowcast row, tables, JSON figures, and history workbook
  are mutually consistent.

## Minimal Checks

Before running MATLAB scripts manually, load the project path:

```matlab
setup_itnow
```

From the terminal:

```bash
matlab -batch "setup_itnow; which GetData; which GetHistFcast; which RunITNOWUpdate; which DeployITNOWWebsite"
```

Do not commit raw data, generated outputs, local cache files, temporary
MATLAB files, or machine-specific files.

## Website Deployment Safety

ITNOW does not commit, push, or deploy `andreaviselli.github.io`. When
`update_website=true`, it only stages file changes in the local website
checkout. The website checkout must be clean before staging; otherwise the
pipeline aborts before data downloads or model estimation begin.
