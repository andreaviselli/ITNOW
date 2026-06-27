#!/usr/bin/env python3
"""Build current ITNOW figures, tables, and optional website artifacts."""

from __future__ import annotations

import argparse
import json
import math
import re
import shutil
import subprocess
from pathlib import Path

import numpy as np
import pandas as pd
import plotly.graph_objects as go
from scipy.stats import gaussian_kde


NOWCAST_COLUMN = "BG_4"
SUMMARY_NOWCAST_COLUMNS = {"Mean", "Median", "Naive"}
COMBINATION_COLUMN_PATTERN = re.compile(r"^BG(?:_|$)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-path", required=True)
    parser.add_argument("--vintage", required=True)
    parser.add_argument("--eval-end", required=True)
    parser.add_argument("--website-root", default="")
    parser.add_argument("--no-update-website", action="store_true")
    return parser.parse_args()


def load_inputs(base_path: Path, vintage: str) -> tuple[pd.DataFrame, pd.DataFrame]:
    path_predicted = base_path / "HISTORY" / "PREDICTION" / f"{vintage}_fcasts_covid.csv"
    path_actual = base_path / "DATA" / "GDP_History" / f"GDP{vintage}.csv"

    y_predicted = pd.read_csv(path_predicted)
    y_predicted["Time"] = pd.to_datetime(y_predicted["Time"])
    y_predicted = y_predicted.set_index("Time")

    y_actual = pd.read_csv(path_actual)
    y_actual["Time"] = pd.to_datetime(y_actual["Time"])
    y_actual = y_actual.set_index("Time")
    return y_predicted, y_actual


def prepare_nowcasts(
    y_predicted: pd.DataFrame, y_actual: pd.DataFrame, est_end: str, eval_end: str
) -> tuple[pd.DataFrame, pd.DataFrame, pd.Timestamp, int, float]:
    y_actual = y_actual.loc[est_end:eval_end].copy()
    if NOWCAST_COLUMN not in y_predicted.columns:
        raise RuntimeError(f"Expected full BG nowcast column missing: {NOWCAST_COLUMN}")

    y_level = y_actual[["Level"]].copy()
    first_fcast_idx = y_predicted[NOWCAST_COLUMN].first_valid_index()
    first_fcast_loc = y_predicted.index.get_loc(first_fcast_idx)

    level_nowcast = y_actual["Level"].shift(3) * (1 + y_predicted[NOWCAST_COLUMN])
    y_level[NOWCAST_COLUMN] = np.nan
    y_level.iloc[first_fcast_loc:, y_level.columns.get_loc(NOWCAST_COLUMN)] = (
        level_nowcast.iloc[first_fcast_loc:]
    )
    y_level["Level"] = y_level["Level"] / 1000
    y_level[NOWCAST_COLUMN] = y_level[NOWCAST_COLUMN] / 1000

    y_growth = y_actual.copy()
    alpha = 0.05
    y_growth[NOWCAST_COLUMN] = y_predicted[NOWCAST_COLUMN]
    errors = y_growth["Growth"] - y_growth[NOWCAST_COLUMN]
    y_growth[f"{NOWCAST_COLUMN}_Low"] = y_growth[NOWCAST_COLUMN] + errors.quantile(alpha)
    y_growth[f"{NOWCAST_COLUMN}_Upp"] = y_growth[NOWCAST_COLUMN] + errors.quantile(1 - alpha)

    return y_growth, y_level, first_fcast_idx, first_fcast_loc, alpha


def model_nowcast_columns(y_predicted: pd.DataFrame) -> list[str]:
    return [
        column
        for column in y_predicted.columns
        if column not in SUMMARY_NOWCAST_COLUMNS and not COMBINATION_COLUMN_PATTERN.match(column)
    ]


def write_figures(
    out_dir: Path,
    y_predicted: pd.DataFrame,
    y_growth: pd.DataFrame,
    y_level: pd.DataFrame,
    first_fcast_idx: pd.Timestamp,
    first_fcast_loc: int,
    alpha: float,
) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    width0 = 800
    height0 = 500

    last_date = y_growth.index[-1]
    last_nowcast_val = y_growth[NOWCAST_COLUMN].iloc[-1]

    valid_growth = y_growth.loc[first_fcast_idx:].copy()
    in_between_x = np.concatenate([valid_growth.index.values, valid_growth.index.values[::-1]])
    in_between_y = pd.concat(
        [valid_growth[f"{NOWCAST_COLUMN}_Low"], valid_growth[f"{NOWCAST_COLUMN}_Upp"][::-1]]
    ).values

    fig1 = go.Figure()
    fig1.add_trace(
        go.Scatter(
            x=in_between_x,
            y=in_between_y,
            fill="toself",
            fillcolor="rgba(130, 130, 130, 0.5)",
            line={"color": "rgba(255, 255, 255, 0)"},
            name=f"{(1 - 2 * alpha):.0%} Prediction Interval",
            hovertemplate="%{x|%b %Y}<br>PI Bound: %{y:.3%}<extra></extra>",
        )
    )
    fig1.add_hline(y=0, line_dash="dot", line_color="black", line_width=1)
    fig1.add_trace(
        go.Scatter(
            x=y_growth.index,
            y=y_growth["Growth"],
            mode="markers",
            name="Quarterly Nominal GDP Growth",
            marker={"size": 12, "color": "#0072BD"},
            hovertemplate="%{x|%b %Y}<br>GDP Growth: %{y:.3%}<extra></extra>",
        )
    )
    fig1.add_trace(
        go.Scatter(
            x=y_growth.index,
            y=y_growth[NOWCAST_COLUMN],
            mode="lines",
            name="Historical Nowcast",
            line={"color": "#D95319", "width": 3},
            hovertemplate="%{x|%b %Y}<br>Nowcast: %{y:.3%}<extra></extra>",
        )
    )
    fig1.add_trace(
        go.Scatter(
            x=[last_date],
            y=[last_nowcast_val],
            mode="markers",
            marker={"size": 20, "color": "#EDB120", "line": {"width": 2, "color": "DarkSlateGrey"}},
            name=f"{last_date.strftime('%b')}-{last_date.year} Nowcast ({last_nowcast_val:.3%})",
            hovertemplate="%{x|%b %Y}<br>Latest Nowcast: %{y:.3%}<extra></extra>",
        )
    )
    fig1.update_layout(
        yaxis_title="Quarterly Nominal GDP Growth",
        yaxis_tickformat=".1%",
        xaxis={"tickformat": "%Y", "tickangle": 45, "dtick": "M12"},
        width=width0,
        height=height0,
        legend={"orientation": "h", "yanchor": "bottom", "y": 1.02, "xanchor": "center", "x": 0.5},
        font={"family": "Times New Roman", "size": 18},
    )
    fig1.write_json(out_dir / "GDP_Growth_Ncast.json")

    fig2 = go.Figure()
    fig2.add_trace(
        go.Bar(
            x=y_level.index,
            y=y_level["Level"],
            name="Quarterly GDP (2020 Chain Linked)",
            marker={"color": "#0072BD"},
            hovertemplate="%{x|%b %Y}<br>Level: %{y:.3f} Bln \u20ac<extra></extra>",
        )
    )
    y_level_quarterly = y_level.iloc[first_fcast_loc::3]
    fig2.add_trace(
        go.Scatter(
            x=y_level_quarterly.index,
            y=y_level_quarterly[NOWCAST_COLUMN],
            mode="lines",
            name="Historical Nowcast",
            line={"color": "#D95319", "width": 4},
            hovertemplate="%{x|%b %Y}<br>Nowcast: %{y:.3f} Bln \u20ac<extra></extra>",
        )
    )
    last_level_nowcast = y_level[NOWCAST_COLUMN].iloc[-1]
    fig2.add_hline(y=last_level_nowcast, line_dash="dot", line_color="#D95319")
    fig2.add_annotation(
        x=y_level.index[-25],
        y=last_level_nowcast + 10,
        text=f"{last_level_nowcast:.3f} billions of \u20ac",
        showarrow=False,
        font={"family": "Times New Roman", "size": 20},
    )
    fig2.add_trace(
        go.Scatter(
            x=[last_date],
            y=[last_level_nowcast],
            mode="markers",
            marker={"size": 15, "color": "#EDB120", "line": {"width": 2, "color": "DarkSlateGrey"}},
            name=f"Q{last_date.quarter}-{last_date.year} Nowcast",
            hovertemplate="%{x|%b %Y}<br>Latest Nowcast: %{y:.3f} Bln \u20ac<extra></extra>",
        )
    )
    fig2.update_layout(
        yaxis={"title": "Nominal GDP (billions of euros)", "range": [350, 530], "tickvals": list(range(400, 601, 50))},
        xaxis={"tickformat": "%Y", "tickangle": 45, "dtick": "M12"},
        font={"family": "Times New Roman", "size": 18},
        width=width0,
        height=height0,
        legend={"orientation": "h", "yanchor": "bottom", "y": 1.02, "xanchor": "center", "x": 0.5},
    )
    fig2.write_json(out_dir / "GDP_Level_Ncast.json")

    nowcast_columns = model_nowcast_columns(y_predicted)
    last_nowcasts = y_predicted.loc[y_predicted.index[-1], nowcast_columns].dropna()
    if last_nowcasts.empty:
        raise RuntimeError("No model nowcasts are available for the latest density plot.")
    nowcast_values = last_nowcasts.values
    kde = gaussian_kde(nowcast_values)
    x_range = np.linspace(nowcast_values.min() - 0.005, nowcast_values.max() + 0.005, 500)

    fig3 = go.Figure()
    fig3.add_trace(
        go.Scatter(
            x=x_range,
            y=kde(x_range),
            mode="lines",
            fill="tozeroy",
            fillcolor="rgba(0, 114, 189, 0.2)",
            line={"color": "#0072BD", "width": 2},
            name="Density (KDE)",
        )
    )
    marker_style = {"size": 15, "line": {"width": 2, "color": "DarkSlateGrey"}}
    for key, label, color in [
        ("BG_4", "Full", "Teal"),
        ("Median", "Median", "ForestGreen"),
    ]:
        value = y_predicted[key].iloc[-1] if key in y_predicted.columns else None
        if value is not None and not pd.isna(value):
            fig3.add_trace(
                go.Scatter(
                    x=[value],
                    y=kde(value),
                    mode="markers",
                    marker={"color": color, **marker_style},
                    name=f"{label}: {value:.3%}",
                )
            )
    fig3.update_layout(
        xaxis_title="Quarterly Nominal GDP Growth",
        yaxis_title="Density",
        xaxis_tickformat=".2%",
        font={"family": "Times New Roman", "size": 18},
        width=width0,
        height=height0,
        legend={"orientation": "h", "yanchor": "bottom", "y": 1.02, "xanchor": "center", "x": 0.5},
    )
    fig3.write_json(out_dir / "GDP_KDE_Ncast.json")


def build_tables(y_growth: pd.DataFrame, y_level: pd.DataFrame, alpha: float) -> tuple[pd.DataFrame, pd.DataFrame]:
    last_date = y_growth.index[-1]
    nowtab1 = pd.DataFrame(
        {
            "QoQ % Change (back)": [100 * y_growth[NOWCAST_COLUMN].iloc[-2]],
            "QoQ % Change (now)": [100 * y_growth[NOWCAST_COLUMN].iloc[-1]],
            f"{int(alpha * 100)}% Pr. (now)": [100 * y_growth[f"{NOWCAST_COLUMN}_Low"].iloc[-1]],
            f"{int((1 - alpha) * 100)}% Pr. (now)": [100 * y_growth[f"{NOWCAST_COLUMN}_Upp"].iloc[-1]],
        },
        index=[last_date.strftime("%Y-%m-%d")],
    ).round(2)

    yoy_growth = 100 * (y_level[NOWCAST_COLUMN].iloc[-1] - y_level["Level"].iloc[-13]) / y_level["Level"].iloc[-13]
    prev_year = y_level.index.year == (last_date.year - 1)
    last_level_prev_year = y_level.loc[prev_year, "Level"].iloc[-1]
    carry_growth = 100 * (y_level[NOWCAST_COLUMN].iloc[-1] - last_level_prev_year) / last_level_prev_year

    nowtab2 = pd.DataFrame(
        {
            "QoQ % Change": [100 * y_growth[NOWCAST_COLUMN].iloc[-1]],
            "YoY % Change": [yoy_growth],
            "Carry Over": [carry_growth],
            "Level (Bln \u20ac)": [y_level[NOWCAST_COLUMN].iloc[-1]],
        },
        index=[f"Q{last_date.quarter}-{last_date.year}"],
    ).round(2)
    return nowtab1, nowtab2


def write_tables(base_path: Path, vintage: str, nowtab1: pd.DataFrame, nowtab2: pd.DataFrame) -> None:
    out_dir = base_path / "HISTORY" / "RT_TABLES"
    out_dir.mkdir(parents=True, exist_ok=True)
    nowtab1.to_csv(out_dir / f"growth_fcast_{vintage}.csv")
    nowtab2.to_csv(out_dir / f"level_fcast_{vintage}.csv")


def finite_or_none(value: float | int | None) -> float | None:
    if value is None:
        return None
    if isinstance(value, float | np.floating) and (math.isnan(value) or math.isinf(value)):
        return None
    return float(value)


def json_ready(value):
    if isinstance(value, dict):
        return {key: json_ready(item) for key, item in value.items()}
    if isinstance(value, list):
        return [json_ready(item) for item in value]
    if isinstance(value, pd.Timestamp):
        return value.date().isoformat()
    if isinstance(value, np.integer):
        return int(value)
    if isinstance(value, int):
        return value
    if isinstance(value, float | np.floating):
        return finite_or_none(value)
    return value


def write_payload_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(json_ready(payload), indent=2, allow_nan=False), encoding="utf-8")


def reference_quarter_for_release(last_date: pd.Timestamp) -> tuple[int, int]:
    quarter = int(last_date.quarter)
    year = int(last_date.year)
    if last_date.month in (3, 6, 9, 12):
        return quarter, year
    quarter -= 1
    if quarter == 0:
        return 4, year - 1
    return quarter, year


def istat_release_line(quarter: int, year: int) -> str:
    url = f"https://www.istat.it/en/press-release/preliminary-estimate-of-gdp-q{quarter}-{year}/"
    return (
        f"The latest ISTAT release (Q{quarter}:{year}, preliminary estimate of GDP) "
        f"can be found [here]({url})."
    )


def replace_first_match(text: str, pattern: str, replacement: str, label: str, flags: int = 0) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise RuntimeError(f"Could not update website {label}; expected exactly one match.")
    return updated


def reference_section_snapshot(text: str) -> str:
    match = re.search(r"(^## [^\n]*Reference Quarter Nowcast[^\n]*\n.*?)(?=^## |\Z)", text, flags=re.S | re.M)
    if match is None:
        raise RuntimeError("Could not find the website reference-quarter section.")
    return match.group(1)


def build_payload(vintage: str, eval_end: str, y_growth: pd.DataFrame, nowtab1: pd.DataFrame, nowtab2: pd.DataFrame) -> dict:
    last_date = y_growth.index[-1]
    is_quarter_end = last_date.month in (3, 6, 9, 12)
    release_quarter, release_year = reference_quarter_for_release(last_date)
    quarter_label = f"Q{last_date.quarter}" if is_quarter_end else "N/A"
    preliminary = y_growth["Growth"].iloc[-1]
    payload = {
        "vintage": vintage,
        "eval_end": eval_end,
        "is_quarter_end": is_quarter_end,
        "monthly_update": last_date.strftime("%b, %Y"),
        "reference_quarter_update": f"Q{release_quarter}-{release_year}",
        "nowcast_quarter": f"Q{last_date.quarter}-{last_date.year}",
        "istat_release": {
            "quarter": release_quarter,
            "year": release_year,
            "line": istat_release_line(release_quarter, release_year),
        },
        "history_row": {
            "Time": pd.to_datetime(vintage, format="%Y%m%d").date().isoformat(),
            "Quarter": quarter_label,
            "Month": int(last_date.month),
            "Year": int(last_date.year),
            "Backcast": finite_or_none(nowtab1.iloc[0, 0] / 100),
            "Nowcast": finite_or_none(nowtab1.iloc[0, 1] / 100),
            "5Perc": finite_or_none(nowtab1.iloc[0, 2] / 100),
            "95Perc": finite_or_none(nowtab1.iloc[0, 3] / 100),
            "Nowcast (YoY)": finite_or_none(nowtab2["YoY % Change"].iloc[0] / 100)
            if is_quarter_end
            else "N/A",
            "Preliminary": finite_or_none(preliminary) if pd.notna(preliminary) else "N/A",
        },
        "tables": {
            "growth": nowtab1.reset_index(names="date").to_dict(orient="records")[0],
            "level": nowtab2.reset_index(names="quarter").to_dict(orient="records")[0],
        },
    }
    return payload


def update_index_md(path: Path, payload: dict, nowtab1: pd.DataFrame, nowtab2: pd.DataFrame) -> None:
    text = path.read_text(encoding="utf-8")

    figure3_caption = (
        "*Figure 3: History of the Italian quarterly nominal GDP level nowcasts using the full model-space "
        "Bates-Granger combination and realizations in 2020 chain-linked values (billions of euros). "
        "Prior to the latest nowcast, pseudo-real-time nowcasts are displayed.*"
    )
    text = replace_first_match(
        text,
        r"\*Figure 3: History of the Italian quarterly [Nn]ominal GDP level nowcasts .*?\*",
        figure3_caption,
        "Figure 3 caption",
        flags=re.S,
    )
    table2_caption = (
        "*Table 2: Nowcasted QoQ and YoY growth rates, carry-over annual effect, and GDP level "
        "from the full model-space Bates-Granger combination (see Figure 3). Note that the "
        "carry-over annual effect is unavailable for the first quarter of the year, and coincides "
        "with the YoY % Change in the last quarter.*"
    )
    text = replace_first_match(
        text,
        r"\*Table 2: Nowcasted QoQ and YoY growth rates, carry-over annual effect, and GDP level .*?\*",
        table2_caption,
        "Table 2 caption",
        flags=re.S,
    )

    original_reference_section = reference_section_snapshot(text)

    text = replace_first_match(
        text,
        r"(## .*Quarterly Growth Nowcast Density \(Last Update: ).*?(\))",
        rf"\g<1>{payload['monthly_update']}\2",
        "monthly growth heading",
    )

    figure1_caption = (
        '*Figure 1: Kernel density estimate of the latest Italian quarterly nominal GDP growth nowcasts '
        'in 2020 chain-linked values. Full corresponds to the time-varying Bates-Granger combination '
        'using the full model space, while Median corresponds to the median nowcast. This density describes the '
        'cross-sectional distribution of current model nowcasts and is not the source of the empirical '
        'prediction interval reported below.*'
    )
    text = replace_first_match(
        text,
        r"\*Figure 1: Kernel density estimate .*?\*",
        figure1_caption,
        "Figure 1 caption",
        flags=re.S,
    )

    figure2_caption = (
        "*Figure 2: History of the Italian quarterly nominal GDP growth nowcasts using the full model-space "
        "Bates-Granger combination and realizations in 2020 chain-linked values. Prior to the "
        "latest nowcast, pseudo-real-time nowcasts are displayed. The shaded band is a 90% empirical "
        "prediction interval: at each date, the 5th and 95th percentiles of the historical "
        "full-combination nowcast errors are added to that date's full-combination nowcast. "
        "The interval is therefore not the cross-model distribution of current forecasts and is not "
        "mechanically centered around the cross-sectional median nowcast.*"
    )
    text = replace_first_match(
        text,
        r"\*Figure 2: History of the Italian quarterly nominal GDP growth nowcasts .*?\*",
        figure2_caption,
        "Figure 2 caption",
        flags=re.S,
    )
    if payload["is_quarter_end"]:
        text = replace_first_match(
            text,
            r"(## .*Reference Quarter Nowcast \(Last Update: ).*?(\))",
            rf"\g<1>{payload['nowcast_quarter']}\2",
            "reference-quarter heading",
        )

    growth_row = nowtab1.iloc[0]
    growth_table = (
        "| QoQ % Change (back) | QoQ % Change (now) | 5% Pr. (now) | 95% Pr. (now) |\n"
        "|----------------------|--------------------|---------------|---------------|\n"
        f"| {growth_row.iloc[0]:.2f}                 | {growth_row.iloc[1]:.2f}               | "
        f"{growth_row.iloc[2]:.2f}         | {growth_row.iloc[3]:.2f}          |"
    )
    text = re.sub(
        r"\| QoQ % Change \(back\) \| QoQ % Change \(now\) \| 5% Pr\. \(now\) \| 95% Pr\. \(now\) \|\n"
        r"\|[-| ]+\|\n"
        r"\|.*\|",
        growth_table,
        text,
    )

    if payload["is_quarter_end"]:
        level_row = nowtab2.iloc[0]
        level_table = (
            "| QoQ % Change  | YoY % Change | Carry-Over  | Level (Billion \u20ac) |\n"
            "|---------------|--------------|-------------|--------|\n"
            f"| {level_row.iloc[0]:.2f}          | {level_row.iloc[1]:.2f}         | "
            f"{level_row.iloc[2]:.2f}        | {level_row.iloc[3]:.2f} |"
        )
        text = re.sub(
            r"\| QoQ % Change  \| YoY % Change \| Carry-Over  \| Level \(Billion .+?\) \|\n"
            r"\|[-| ]+\|\n"
            r"\|.*\|",
            level_table,
            text,
        )
    else:
        updated_reference_section = reference_section_snapshot(text)
        if updated_reference_section != original_reference_section:
            raise RuntimeError("Non-quarter-end website staging changed the reference-quarter section.")

    table1_caption = (
        "*Table 1: Latest full model-space Bates-Granger nowcast and 90% empirical prediction interval bounds. "
        "The bounds are obtained from historical full-combination nowcast errors, not from the "
        "cross-sectional distribution of current model nowcasts (see Figure 2).*"
    )
    text = replace_first_match(
        text,
        r"\*Table 1: .*?\*",
        table1_caption,
        "Table 1 caption",
        flags=re.S,
    )
    text = replace_first_match(
        text,
        r"The latest ISTAT release \(Q\d:\d{4}, preliminary estimate of GDP\) can be found \[here\]\([^)]+\)\.",
        payload["istat_release"]["line"],
        "ISTAT release link",
    )
    path.write_text(text, encoding="utf-8")


def update_history_xlsx(path: Path, row: dict) -> None:
    from openpyxl import load_workbook

    wb = load_workbook(path)
    ws = wb["NOWCAST"]
    headers = [cell.value for cell in ws[1]]
    values = [row.get(header) for header in headers]

    existing_row = None
    first_blank_row = None
    for idx in range(2, ws.max_row + 1):
        time_value = ws.cell(idx, 1).value
        month_value = ws.cell(idx, 3).value
        year_value = ws.cell(idx, 4).value
        if time_value is None and month_value is None and year_value is None:
            if first_blank_row is None:
                first_blank_row = idx
            continue
        if time_value is None:
            continue
        if (
            str(pd.to_datetime(time_value).date()) == row["Time"]
            and month_value == row["Month"]
            and year_value == row["Year"]
        ):
            existing_row = idx
            break

    target_row = existing_row or first_blank_row or ws.max_row + 1
    for col_idx, value in enumerate(values, start=1):
        ws.cell(target_row, col_idx).value = value
    wb.save(path)


def ensure_clean_git_worktree(path: Path) -> None:
    if not (path / ".git").exists():
        return
    result = subprocess.run(
        ["git", "-C", str(path), "status", "--porcelain"],
        check=True,
        capture_output=True,
        text=True,
    )
    if result.stdout.strip():
        raise RuntimeError(
            "Website checkout has uncommitted changes. "
            "Commit, stash, or discard them before staging ITNOW website files."
        )


def update_website(website_root: Path, figure_dir: Path, payload: dict, nowtab1: pd.DataFrame, nowtab2: pd.DataFrame) -> None:
    ensure_clean_git_worktree(website_root)

    static_dir = website_root / "static" / "ITNOW"
    content_path = website_root / "content" / "itnow" / "index.md"
    if not content_path.exists():
        raise RuntimeError(f"Website ITNOW page not found: {content_path}")

    static_dir.mkdir(parents=True, exist_ok=True)

    figure_names = ["GDP_Growth_Ncast.json", "GDP_KDE_Ncast.json"]
    if payload["is_quarter_end"]:
        figure_names.append("GDP_Level_Ncast.json")
    for name in figure_names:
        if not (figure_dir / name).exists():
            raise RuntimeError(f"Expected figure was not generated: {figure_dir / name}")

    backups: dict[Path, bytes | None] = {}
    targets = [static_dir / name for name in figure_names]
    targets.extend([static_dir / "latest_itnow.json", content_path, static_dir / "ITNOW_History.xlsx"])
    for target in targets:
        backups[target] = target.read_bytes() if target.exists() else None

    try:
        for name in figure_names:
            shutil.copy2(figure_dir / name, static_dir / name)

        write_payload_json(static_dir / "latest_itnow.json", payload)
        update_index_md(content_path, payload, nowtab1, nowtab2)

        history_path = static_dir / "ITNOW_History.xlsx"
        if history_path.exists():
            update_history_xlsx(history_path, payload["history_row"])
    except Exception:
        for target, content in backups.items():
            if content is None:
                if target.exists():
                    target.unlink()
            else:
                target.write_bytes(content)
        raise


def main() -> None:
    args = parse_args()
    base_path = Path(args.base_path)
    vintage = args.vintage
    eval_end = args.eval_end
    est_end = "2006-04-01"

    y_predicted, y_actual = load_inputs(base_path, vintage)
    y_growth, y_level, first_fcast_idx, first_fcast_loc, alpha = prepare_nowcasts(
        y_predicted, y_actual, est_end, eval_end
    )

    figure_dir = base_path / "HISTORY" / "FIGURES" / f"json_{vintage}"
    write_figures(figure_dir, y_predicted, y_growth, y_level, first_fcast_idx, first_fcast_loc, alpha)
    nowtab1, nowtab2 = build_tables(y_growth, y_level, alpha)
    write_tables(base_path, vintage, nowtab1, nowtab2)

    payload = build_payload(vintage, eval_end, y_growth, nowtab1, nowtab2)
    write_payload_json(figure_dir / "latest_itnow.json", payload)

    if not args.no_update_website:
        if not args.website_root:
            raise SystemExit("--website-root is required unless --no-update-website is used")
        update_website(Path(args.website_root), figure_dir, payload, nowtab1, nowtab2)

    print(f"Built current nowcast artifacts for vintage {vintage}.")


if __name__ == "__main__":
    main()
