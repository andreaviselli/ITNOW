---
title: "ITNOW"
date: 2023-11-19T22:38:36+01:00
draft: false
---

## Nowcasting Italian Real Gross Domestic Product

We provide monthly nowcasts of Italian quarterly real Gross Domestic Product in **2020 chain-linked terms**.
The nowcasting model is based on the industrial production index, the EUROCOIN indicator, and two static principal-component factors from a small panel of economic time series, in a linear bridge equation.

{{< itnow_summary >}}

Live releases begin in **November 2026**, starting with the nowcast for **October 2026**.

## Historical Quarterly Growth Nowcasts

&nbsp;

{{< itnow_plot file="GDP_Growth_Ncast.json" >}}

*Figure 1: Quarterly real GDP growth (quarter-on-quarter, % change) nowcasts and realizations in chain-linked terms. The shaded areas correspond to empirical 90% prediction intervals, based on earlier forecast errors from the same month within each quarter; the first interval requires 40 released quarterly errors. The October 2026 line marks the first reference month for live releases; nowcasts before October 2026 are pseudo real time.*

&nbsp;

{{< itnow_table kind="growth" >}}

*Table 1: Previous-quarter real GDP growth, latest-quarter nowcast, and empirical 5–95% prediction interval.*

&nbsp;

## GDP Level and Growth

&nbsp;

{{< itnow_plot file="GDP_Level_Ncast.json" >}}

*Figure 2: Quarterly real GDP level nowcasts and realizations in 2020 chain-linked terms (billions of euros). The shaded areas correspond to empirical 90% prediction intervals. The October 2026 line marks the first reference month for live releases; nowcasts before October 2026 are pseudo real time.*

&nbsp;

{{< itnow_table kind="measures" >}}

*Table 2: Real GDP QoQ and YoY percentage changes, annual carry-over growth and level. See the [methodological note on GDP measures]({{< itnow_link file="GDP_MEASURES.pdf" >}}) for more details.*

&nbsp;

## Description

The preliminary estimate of GDP is released by ISTAT, the Italian statistical agency, with a one-month delay after the end of the reference quarter. Nowcasting allows us to assess real GDP growth before that quarterly figure becomes available by exploiting the co-movement among economic indicators at the monthly frequency.

Our nowcasting model is a quarterly bridge equation using industrial-production growth, the EUROCOIN index, and two factors that summarise a small panel of monthly indicators, that enter the equation as quarterly averages. We re-estimate the model each month using an expanding window. The [one-page model note]({{< itnow_link file="MODEL.pdf" >}}) describes the equation, factor aggregation, missing observations and publication delays. The [GDP measures note]({{< itnow_link file="GDP_MEASURES.pdf" >}}) explains how we convert the forecast into the measures in Table 2.

&nbsp;

## Code, downloads, and links

> 🧑‍💻 Source code is available on [**GitHub**](https://github.com/andreaviselli/ITNOW).

{{< itnow_source >}}

Available for download:
- [Real-time nowcast history]({{< itnow_link file="ITNOW_History.xlsx" >}}).
- [Pseudo real-time nowcast history]({{< itnow_link file="Retrospective_Nowcasts.csv" >}}).
- [Pseudo real-time performance report]({{< itnow_link file="ITNOW_Performance.pdf" >}}).

The Excel file includes the INFO definitions, DATA descriptions and a NOWCAST sheet. The first live nowcast entry is October 2026, published in November 2026.
