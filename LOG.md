# IT-NOW Log

Started in June 2025.

## 16-06-2026

Added the first automation layer for unattended ITNOW updates.

- Added `RunITNOWUpdate.m` as the orchestration entry point.
- Added shared configuration and helper functions for previous-month
  evaluation dates, latest local vintage lookup, ISTAT edition probing, and
  FTSE MIB acquisition.
- Updated `GetData.m` to use shared configuration, optional automatic ISTAT
  edition discovery, non-interactive execution, FTSE MIB helper handling, and
  vintage metadata output.
- Updated `GetHistFcast.m` to run from the project root, accept orchestrator
  configuration, and select the latest local vintage when none is supplied.
- Added `scripts/build_current_nowcast.py` to replace the operational role of
  `GetCurrNcast.ipynb` for report generation and website artifact staging.
- Replaced the manual README with a project overview and added `PIPELINE.md`
  for operating details.
- Clarified launch commands and remaining hardening work in the README and
  pipeline documentation.
- Removed generated local cache clutter outside `DATA/` and `HISTORY/`.
- Clarified the default `Eval_End` rule with concrete examples.
- Added a STOOQ downloader that handles the site's lightweight JavaScript
  verification flow and rejects HTML challenge pages as invalid CSV files.
- Updated the default FTSE MIB source URL to the canonical daily STOOQ CSV
  endpoint `https://stooq.com/q/d/l/?s=^fmib&i=d`.
- Added `DATA/FTSEMIB.csv` as a batch-safe cached fallback when STOOQ blocks
  scripted downloads.
- Added quiet setup support and stage-level progress output to
  `RunITNOWUpdate.m`.
- Clarified that manually downloaded STOOQ data must be renamed
  `FTSEMIB.csv` and placed in `DATA/`.
- Added website staging safeguards: clean-worktree check, rollback of touched
  files on staging failure, and explicit documentation that ITNOW does not
  commit or deploy `andreaviselli.github.io`.
- Moved the website dirty-worktree check into an early `RunITNOWUpdate`
  preflight stage so the pipeline fails before downloads or estimation.
- Added per-candidate ISTAT edition probe logging, shortened the default
  edition-probe timeout, and documented the explicit-edition override command.
- Improved ISTAT discovery diagnostics, stopped preliminary probing when all
  final GDP probes fail, and documented that UI/API mismatches should be
  treated as API/network/IP issues.
- Fixed FTSE MIB fallback validation so a valid cached `DATA/FTSEMIB.csv` is
  used when STOOQ blocks scripted downloads.
- Suppressed known Bank of Italy table-header warnings and replaced verbose
  `GetData.m` download messages with compact source-progress output.
- Added `DeployITNOWWebsite.m` and latest-prediction vintage lookup so website
  artifacts can be staged from existing forecast outputs without rerunning the
  full pipeline.
- Isolated `GetData.m` and `GetHistFcast.m` execution inside helper functions
  so script-level `clearvars` cannot clear orchestrator state.
- Fixed website history workbook updates when the `NOWCAST` sheet contains
  blank rows.
- Prevented non-quarter-end website staging from overwriting the reference
  quarter section or `GDP_Level_Ncast.json`; quarterly website artifacts are
  now refreshed only for March, June, September, and December evaluation ends.
- Made the website metadata manifest strict JSON by converting non-finite
  values to `null`.
- Added automatic public-page updates for the ISTAT preliminary GDP release
  link, using the latest published reference quarter implied by `Eval_End`.
- Clarified the public-page prediction interval text: the interval is based on
  historical skilled-combination nowcast errors, not on the current
  cross-model forecast distribution, and is not mechanically centered around
  the top-five skilled combination.
- Added a page-update guard that fails non-quarter-end deployments if the
  reference-quarter website section would be changed.

## 10-05-2026

ARDL removed from the final nowcast combination due to poor performance overall.

## 17-01-2026

The infrastructure has undergone a systematic revision, and multiple changes were made.

## 14-06-2025

To match vector sizes, we added the command below on line 177. Check this again next month.

```matlab
Quarters = Quarters(1:end-1); % Check next time whether this is correct.
```
