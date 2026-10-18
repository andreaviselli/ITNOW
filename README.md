# ITNOW

Monthly nowcasts of Italian quarterly GDP in chain-linked terms. The model
is an expanding OLS bridge with industrial-production growth, quarterly mean
EUROCOIN and two static PCA factors. Factors use fixed five-month weights
`[1,2,3,2,1]`. There are no COVID signs or caps.

## Run

Use MATLAB with Statistics and Machine Learning Toolbox, Python 3.10 or
later, and the packages in `requirements.txt`.

```bash
python3 -m pip install -r requirements.txt
matlab -batch "setup_itnow; run_update"
```

The reference month is the last completed month. To reproduce the verified
September 2026 result from the saved 9 October snapshot:

```matlab
setup_itnow
run_update('download',false,'vintage','20261009', ...
    'eval_end',datetime(2026,9,1))
```

Set `python` explicitly if packages use another interpreter. To stage the
local website, add `'update_website',true,'website_root','/path/to/website'`.
This never commits or publishes. To rebuild reporting without estimation:

```bash
python3 scripts/build_report.py --base-path . --vintage 20261009
```

## Files

| Path | Purpose |
| --- | --- |
| `_programs/run_update.m` | Pipeline entry point |
| `_programs/get_data.m` | Downloads and provider metadata |
| `_programs/estimate_nowcasts.m` | Expanding monthly estimation |
| `_functions/` | Source readers, transformations and bridge calculations |
| `scripts/build_report.py` | GDP conversions, intervals, figures and performance |
| `website/content/itnow/index.md` | Editable website text and captions |
| `tests/` | MATLAB and Python checks |

`VERSION` identifies the code release. Methodological notes are supplied on
the website. Local notes, agent guidance and source snapshots are ignored by
Git. Estimation and reporting run independently of these local files.
Website staging uses compiled notes or those already in its assets.

Inputs and outputs are local and ignored by Git. A saved vintage needs
`DATA/sourceYYYYMMDD.csv`, `DATA/GDP_History/GDPYYYYMMDD.csv` and matching
`DATA/VINTAGE_METADATA/vintageYYYYMMDD.json`. The source panel contains
19 indicators and quarterly GDP levels.

Fresh downloads preserve genuine gaps and report failures and fallbacks.
Yahoo continuation needs the pre-September-2026 Stooq history in
`DATA/FTSEMIB.csv`. If OECD access fails, complete official exports in
`DATA/OECD/` can supply those histories, with a warning. Input files are
not distributed with the code.

Forecasts, coefficients and provenance go to `HISTORY/PREDICTION/`.
Reports go to `output/YYYYMMDD/`. The release workbook is
`HISTORY/RELEASES/ITNOW_History.xlsx`. Add a row only after publishing a
release, using its saved `release_record.csv` and metadata. Enter rates
as decimal fractions: divide the record's `_percent` fields by 100.
Copy the updated workbook to the website's `static/ITNOW/` folder.
Reporting and staging do not append releases or overwrite that workbook.
The workbook includes INFO definitions, DATA descriptions and an empty
NOWCAST sheet. Its first forecast entry will be October 2026,
published in November 2026. Earlier releases are stored locally in the
archive. Retrospective estimates do not enter the release history.

Keep `scripts/`, `tests/` and `website/` in source control: they contain the
report builder, downloader, checks and website templates. Generated assets,
data and release workbooks remain local and ignored.

## Verify

```bash
python3 -m unittest discover -s tests -p test_report.py
matlab -batch "setup_itnow; addpath('tests'); test_model; test_sources; test_confidence; test_market_data; test_download"
matlab -batch "setup_itnow; addpath('tests'); verify_bridge_refactor"
```

The final check needs the saved research reference in
`HISTORY/VALIDATION/combination-research-20261017/bridge_augmentation/`.
All 246 forecasts and 59,655 factor-history rows match up to numerical
rounding.

Historical comparisons use revised data and fixed delays. We selected the
specification after these comparisons; its historical RMSE is not an online
test of the selection decision.
