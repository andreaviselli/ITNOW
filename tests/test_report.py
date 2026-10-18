"""Economic units, causal intervals and report selection for the bridge."""
import importlib.util
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

import numpy as np
import pandas as pd

MODULE = Path(__file__).resolve().parents[1]/"scripts/build_report.py"
spec = importlib.util.spec_from_file_location("build_report", MODULE)
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


class ReportTests(unittest.TestCase):
    def test_exact_growth_and_level(self):
        levels = pd.Series(100., index=pd.period_range("2023Q1", "2024Q1", freq="Q"))
        result = report.measures(.01, pd.Period("2024Q2"), levels)
        self.assertAlmostEqual(result["qoq_percent"], 100*np.expm1(.01))
        self.assertAlmostEqual(result["level_billions"], .1*np.exp(.01))
        self.assertAlmostEqual(result["yoy_percent"], 100*np.expm1(.01))
        self.assertNotEqual(result["qoq_percent"], 1.)

    def test_carry_over_for_each_quarter(self):
        levels = pd.Series([100.]*4+[101., 102., 103.],
                           index=pd.period_range("2023Q1", periods=7, freq="Q"))
        for quarter, expected in [(1, 2.), (2, 1.75), (4, 2.5)]:
            q = pd.Period(f"2024Q{quarter}")
            target = 102. if quarter != 4 else 104.
            value = report.measures(np.log(target/levels.loc[q-1]), q, levels)
            self.assertAlmostEqual(value["carry_over_percent"], expected)

    def test_missing_carry_input_is_not_zero(self):
        levels = pd.Series([100.]*5, index=pd.period_range("2023Q1", periods=5, freq="Q"))
        levels.loc["2023Q2"] = np.nan
        self.assertTrue(np.isnan(report.measures(.01, pd.Period("2024Q2"), levels)["carry_over_percent"]))

    def test_bands_use_same_stage_and_only_released_gdp(self):
        dates = pd.date_range("2000-01-01", periods=15, freq="MS")
        forecasts = pd.Series(np.arange(15)/100, index=dates)
        ends = dates[dates.month % 3 == 0]
        growth = pd.Series([1., 2., 3., 4., 5.], index=ends)
        bands = report.error_bands(forecasts, growth, minimum=4)
        self.assertTrue(bands.lower.loc["2000-12-01"] != bands.lower.loc["2000-12-01"])
        self.assertEqual(bands.n_errors.loc["2001-01-01"], 4)
        past = growth.iloc[:4].to_numpy()-forecasts.iloc[[0, 3, 6, 9]].to_numpy()
        self.assertAlmostEqual(bands.lower.loc["2001-01-01"], forecasts.iloc[12]+np.quantile(past, .05))
        changed = growth.copy()
        changed.iloc[-1] = -900
        pd.testing.assert_frame_equal(report.error_bands(forecasts, changed, minimum=4), bands)

    def test_level_anchor_matches_each_months_target_quarter(self):
        dates = pd.date_range("2024-01-01", periods=6, freq="MS")
        levels = pd.Series([100., 102.], index=pd.period_range("2023Q4", periods=2, freq="Q"))
        anchors = levels.reindex(dates.to_period("Q")-1).to_numpy()
        np.testing.assert_array_equal(anchors, [100., 100., 100., 102., 102., 102.])

    def test_score_excludes_unreleased_quarter(self):
        dates = pd.date_range("2007-04-01", periods=9, freq="MS")
        history = pd.DataFrame({"nowcast": .01, "actual_log": 0., "naive_log": .02,
                                "lower_log": -.01, "upper_log": .03}, index=dates)
        scores = report.score_history(history, pd.Timestamp("2007-12-01"))
        row = scores[(scores.period == "All") & (scores.stage == 0)].iloc[0]
        self.assertEqual(row.n, 6)
        self.assertAlmostEqual(row.rmse, 1.)
        self.assertAlmostEqual(row.relative_naive_rmse, .5)

    def test_live_boundary_uses_reference_month_and_labels_release_month(self):
        dates = pd.date_range("2026-08-01", periods=2, freq="MS")
        actual = pd.Series([.2], index=dates[-1:])
        history = pd.DataFrame({"growth": [.1, .3], "growth_lower": [-.1, .1],
                                "growth_upper": [.3, .5], "level": [100., 101.],
                                "level_lower": [99., 100.], "level_upper": [101., 102.]}, index=dates)
        for is_level in [False, True]:
            chart = report.figure(history, actual, is_level)
            boundary = next(shape for shape in chart.layout.shapes if shape.xref == "x")
            self.assertEqual(pd.Timestamp(boundary.x0), pd.Timestamp("2026-10-01"))
            self.assertIn("Nov 2026", chart.layout.annotations[0].text)
            column = "level" if is_level else "growth"
            np.testing.assert_array_equal(chart.data[2].y, history[column])
            self.assertEqual(chart.data[2].name, "Pseudo-real-time nowcast")

    def test_report_runs_without_local_notes(self):
        with TemporaryDirectory() as folder:
            base = Path(folder)
            for subfolder in ["HISTORY/PREDICTION", "DATA/GDP_History", "DATA/VINTAGE_METADATA"]:
                (base/subfolder).mkdir(parents=True)
            dates = pd.date_range("2005-01-01", "2021-09-01", freq="MS")
            q = dates.month % 3 == 0
            levels = np.full(len(dates), np.nan)
            levels[q] = 100*np.exp(.002*np.arange(q.sum()))
            growth = np.where(q, .002, np.nan)
            pd.DataFrame({"Level": levels, "Growth": growth}, index=dates).to_csv(
                base/"DATA/GDP_History/GDP20211009.csv", index_label="Time")
            origins = pd.date_range("2006-04-01", "2021-09-01", freq="MS")
            pd.DataFrame({"nowcast": .002}, index=origins).to_csv(
                base/"HISTORY/PREDICTION/20211009_bridge.csv", index_label="Time")
            metadata = {"vintage": "20211009", "eval_end": "2021-09-01",
                        "produced_at": "2021-10-09T12:00:00+02:00",
                        "model": "ip_eurocoin_pca_2", "model_version": "test"}
            (base/"HISTORY/PREDICTION/20211009_bridge.json").write_text(json.dumps(metadata))
            (base/"DATA/VINTAGE_METADATA/vintage20211009.json").write_text(json.dumps(
                {"gdp": {"url": "https://example.test/gdp"}}))
            assets = report.build_report(base, "20211009")
            latest = json.loads((assets/"latest_itnow.json").read_text())
            self.assertEqual(latest["last_actual_quarter"], "2021Q2")
            self.assertAlmostEqual(latest["current"]["qoq_percent"], 100*np.expm1(.002))
            self.assertTrue((assets/"GDP_Level_Ncast.json").is_file())
            self.assertFalse((assets/"MODEL.pdf").exists())

    def test_staging_preserves_release_workbooks(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            website, assets, project = root/"site", root/"assets", root/"project"
            destination = website/"static/ITNOW"
            destination.mkdir(parents=True)
            (website/"content").mkdir()
            assets.mkdir()
            (project/"website").mkdir(parents=True)
            for name in ["MODEL.pdf", "GDP_MEASURES.pdf"]:
                (destination/name).write_bytes(b"method note")
            names = ["ITNOW_History.xlsx", "ITNOW_History_pre_bridge.xlsx"]
            for name in names:
                (destination/name).write_bytes(b"published records")
                (assets/name).write_bytes(b"retrospective report")
            (assets/"release_record.csv").write_text("status\nunpublished\n")
            (assets/"latest_itnow.json").write_text("{}")
            report.stage_website(website, assets, project)
            for name in names:
                self.assertEqual((destination/name).read_bytes(), b"published records")
            self.assertFalse((destination/"release_record.csv").exists())
            self.assertTrue((destination/"latest_itnow.json").is_file())


if __name__ == "__main__":
    unittest.main()
