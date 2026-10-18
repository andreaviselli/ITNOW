# ITNOW

Monthly nowcasts of Italian quarterly real GDP in 2020 chain-linked terms. 
The model is a linear bridge equation with industrial-production growth, 
the EUROCOIN index, and two static PCA factors from a small panel of 
economic indicators, all of which are aggregated as quarterly averages.

## Run

Use MATLAB with Statistics and Machine Learning Toolbox, Python 3.10 or
later, and the packages in `requirements.txt`.

```bash
python3 -m pip install -r requirements.txt
matlab -batch "setup_itnow; run_update"
```

To reproduce the September 2026 example, using the saved input files for 
data vintage 20261009 (not included in this repository):

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
the website.

A saved vintage needs `DATA/sourceYYYYMMDD.csv`, `DATA/GDP_History/GDPYYYYMMDD.csv` 
and matching `DATA/VINTAGE_METADATA/vintageYYYYMMDD.json`. The source panel contains
19 indicators and quarterly GDP levels.

When downloading the data, missing observations remain missing and the program 
reports download failures and the use of alternative sources or saved files.
Yahoo! Finance provides the recent FTSEMIB data but needs the pre-September-2026 
Stooq history in `DATA/FTSEMIB.csv`. If the OECD download fails, the program can 
use manually downloaded official CSV files in `DATA/OECD/`, and a warning is
returned when these saved files are used. These input files are not distributed 
with the code.

Forecasts and estimation details are saved in `HISTORY/PREDICTION/`; reports 
are saved in `output/YYYYMMDD/`. Published nowcasts are recorded in 
`HISTORY/RELEASES/ITNOW_History.xlsx`, starting with the October 2026 nowcast 
released in November 2026.

## Tests

Run the reporting and model checks:

```bash
python3 -m unittest discover -s tests -p test_report.py
matlab -batch "setup_itnow; addpath('tests'); test_model; test_sources; test_confidence; test_market_data; test_download"
```
