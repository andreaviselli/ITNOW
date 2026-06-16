# ITNOW Pipeline Architecture

## Entry Points

`RunITNOWUpdate.m` is the orchestrator for unattended operation. It loads the
shared configuration, discovers source vintages, runs the data construction
script, runs the historical forecast script, and invokes the Python reporting
script.

Run the full pipeline from the terminal:

```bash
matlab -batch "setup_itnow; RunITNOWUpdate"
```

Run without touching the website checkout:

```bash
matlab -batch "setup_itnow; RunITNOWUpdate('update_website', false)"
```

This command does not supply an `eval_end` override. The orchestrator therefore
uses the default rule: first day of the previous completed calendar month. For
example, if run on 16 June 2026, it sets `Eval_End = 2026-05-01`.

Console output is organized into five stages: preflight checks, ISTAT edition
discovery, data vintage construction, historical nowcast models, and
current-artifact generation. Each stage prints a progress marker and elapsed
time.

Run with an explicit evaluation end date:

```bash
matlab -batch "setup_itnow; RunITNOWUpdate('eval_end', datetime('2026-04-01'), 'update_website', false)"
```

Run with explicit ISTAT editions, bypassing automatic discovery:

```bash
matlab -batch "setup_itnow; RunITNOWUpdate('update_website', false, 'edition', '2026M5', 'preliminary_ed', '2026M4')"
```

Stage the website from existing forecast outputs without rerunning data
downloads or models:

```bash
matlab -batch "setup_itnow; DeployITNOWWebsite"
```

or for a specific vintage:

```bash
matlab -batch "setup_itnow; DeployITNOWWebsite('vintage', '20260509')"
```

Manual entry points remain available:

```matlab
setup_itnow; GetData
setup_itnow; GetHistFcast
```

## Configuration

Shared defaults live in `ITNOWConfig.m`.

Important defaults:

- `base_path`: project root.
- `run_date`: current date.
- `eval_end`: first day of the previous completed calendar month.
- `auto_discover_istat`: enabled.
- `istat_lookback_months`: 12.
- `istat_probe_timeout`: 15 seconds per edition candidate.
- `ftsemib_mode`: `stooq`.
- `interactive`: disabled.
- `update_website`: enabled.

These can be overridden with name-value pairs:

```matlab
setup_itnow;
RunITNOWUpdate("eval_end", datetime("2026-04-01"), "update_website", false)
```

## Data Vintage Selection

The data vintage is still named by the run date, `YYYYMMDD`, because that is
the date on which the data snapshot is constructed and stored.

ISTAT edition names are selected separately. The automated selector builds
candidate edition strings such as `2026M6`, `2026M5`, and so on, then probes
the final GDP and preliminary GDP endpoints independently. The newest candidate
that returns a parseable response with observations is selected.

If the IstatData web UI lists an edition but the SDMX probe says it is not
available, treat that as an API/network/IP problem rather than proof that the
edition does not exist. In that case, bypass automatic discovery with explicit
editions, for example:

```bash
matlab -batch "setup_itnow; RunITNOWUpdate('update_website', false, 'edition', '2026M5', 'preliminary_ed', '2026M4')"
```

The selected editions and run metadata are written to:

```text
DATA/VINTAGE_METADATA/vintageYYYYMMDD.json
```

## Evaluation End Date

`Eval_End` should generally be the first day of the previous completed month,
not the current month. During most of a month, current-month indicators are
too sparse to support a stable nowcast update. The helper
`ITNOWPreviousCompletedMonth` implements this rule.

Concrete examples:

- run date 16 June 2026 -> `Eval_End = 2026-05-01`;
- run date 1 July 2026 -> `Eval_End = 2026-06-01`;
- run date 31 July 2026 -> `Eval_End = 2026-06-01`.

Manual overrides remain possible through `RunITNOWUpdate` or by passing
variables before running `GetHistFcast.m`.

## FTSE MIB

`GetData.m` now delegates FTSE MIB acquisition to `ITNOWFetchFTSEMIB`.

The default non-interactive mode tries STOOQ:

```text
https://stooq.com/q/d/l/?s=^fmib&i=d
```

The expected CSV columns are `Date`, `Open`, `High`, `Low`, `Close`, and
`Volume`. The pipeline uses `Date` and `Close`.

If this fails, the automated run fails fast rather than hanging. Interactive
mode can still be used for manual file placement.

Because STOOQ may return an access-control page to scripted clients, batch
runs also support a cached manual fallback:

```text
DATA/FTSEMIB.csv
```

Download the CSV manually from `https://stooq.com/q/d/l/?s=^fmib&i=d`, rename
it exactly to `FTSEMIB.csv`, place it in the project `DATA/` folder, and rerun
the pipeline. The final path must be:

```text
DATA/FTSEMIB.csv
```

The file must contain the expected columns and must not end before `Eval_End`,
unless `allow_stale_ftsemib` is explicitly enabled.

## Forecasting

`GetHistFcast.m` now runs from the project root. This is important because the
model scripts read datasets as `DATA/dataYYYYMMDD.csv`.

If no `vintage` variable is supplied, `GetHistFcast.m` selects the newest local
`DATA/dataYYYYMMDD.csv` file.

## Reporting And Website Staging

`scripts/build_current_nowcast.py` replaces the operational role of
`GetCurrNcast.ipynb`. It is parameterized by base path, vintage, and evaluation
end date.

`DeployITNOWWebsite.m` is a MATLAB wrapper around that reporting script for
the common case where `GetData.m` and `GetHistFcast.m` have already completed
but the website files were not staged. It requires:

```text
HISTORY/PREDICTION/YYYYMMDD_fcasts_covid.csv
DATA/GDP_History/GDPYYYYMMDD.csv
```

and does not rerun data ingestion or model estimation.

It writes:

```text
HISTORY/FIGURES/json_YYYYMMDD/GDP_Growth_Ncast.json
HISTORY/FIGURES/json_YYYYMMDD/GDP_Level_Ncast.json
HISTORY/FIGURES/json_YYYYMMDD/GDP_KDE_Ncast.json
HISTORY/FIGURES/json_YYYYMMDD/latest_itnow.json
HISTORY/RT_TABLES/growth_fcast_YYYYMMDD.csv
HISTORY/RT_TABLES/level_fcast_YYYYMMDD.csv
```

When website updating is enabled, it also stages the JSON figures and
`latest_itnow.json` into:

```text
andreaviselli.github.io/static/ITNOW
```

and updates:

```text
andreaviselli.github.io/content/itnow/index.md
andreaviselli.github.io/static/ITNOW/ITNOW_History.xlsx
```

For non-quarter-end evaluation dates, such as May, the website staging step
updates only the monthly growth density, the monthly growth table,
`GDP_Growth_Ncast.json`, `GDP_KDE_Ncast.json`, `latest_itnow.json`, and the
history workbook. The reference-quarter section and `GDP_Level_Ncast.json` are
updated only when `Eval_End` is March, June, September, or December.

The website repository is a deployment target. It should not be committed from
this project automation unless explicitly requested.

Safety rules:

- `update_website=false` never modifies `andreaviselli.github.io`.
- `update_website=true` stages local file edits only; it does not commit, push,
  or deploy the website repository.
- The pipeline aborts during preflight if `update_website=true` and the
  `andreaviselli.github.io` checkout has uncommitted changes.
- If staging fails after it starts, the updater attempts to restore the website
  files it touched.
- Actual publication happens only after the website repo changes are reviewed,
  committed, and pushed through the website repo's normal deployment flow.

## Scheduler

For operation when the local computer is offline, schedule the orchestrator on
a remote runner that has MATLAB access. GitHub Actions is the preferred target
if MATLAB licensing is available there; otherwise use a self-hosted runner that
remains online.

Failure policy:

- retry transient source failures;
- do not publish partial website updates;
- leave the previous public website files unchanged if validation fails;
- report the failure through the CI logs and notification channel.

## Current Implementation Status

Implemented:

- MATLAB orchestrator and shared configuration.
- Automatic previous-month `Eval_End` default.
- ISTAT final and preliminary GDP edition probing.
- Optional automatic STOOQ FTSE MIB download.
- Parameterized current-nowcast report generation.
- Optional staging of website JSON figures, markdown tables, and history
  workbook rows.
- Deploy-only website staging from existing forecast outputs.

Still to harden before unattended publication:

- End-to-end dry run on live data.
- Confirmation that STOOQ remains usable from the intended runner.
- If STOOQ blocks scripted access, documented use of `DATA/FTSEMIB.csv` as the
  cached manual fallback.
- Atomic website update workflow, preferably staging changes first and only
  copying into the website checkout after all outputs pass validation.
- Scheduled remote execution with MATLAB access.
- Notification/reporting for failed data-source checks.
