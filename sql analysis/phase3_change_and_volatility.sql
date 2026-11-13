

CREATE TABLE hhi_by_year AS
SELECT s.material, s.year,
       ROUND(SUM(POW(s.import_value_eur / t.total_eur * 100, 2))) AS hhi
FROM supplier_data s
JOIN material_totals t
  ON s.material = t.material AND s.year = t.year
GROUP BY s.material, s.year;


SHOW TABLES;

SELECT a.material, a.hhi AS hhi_2019, b.hhi AS hhi_2025, b.hhi - a.hhi AS hhi_change
FROM hhi_by_year a
JOIN hhi_by_year b ON a.material = b.material
WHERE a.year = 2019 AND b.year = 2025
ORDER BY hhi_change DESC;


SELECT material,
       ROUND(STDDEV_SAMP(import_price_eur_per_kg) / AVG(import_price_eur_per_kg), 3) AS price_cov
FROM crm_prices
GROUP BY material
ORDER BY price_cov DESC;


SELECT material, year, import_price_eur_per_kg
FROM crm_prices
ORDER BY material, year;



# Phase 3: HHI Change and Price Volatility

## Why we did this

Phase 2 gave us a snapshot: how concentrated each material's supply was in 2025.
That is useful, but a recruiter or analyst would immediately ask two follow-up
questions. Is the concentration getting worse or better over time? And are prices
stable enough to plan around, or do they swing unpredictably?

Phase 3 answers both. HHI change tells us the direction of travel. Price
volatility, measured as coefficient of variation (CoV), tells us how much price
risk sits on top of the supply risk. Together they give the project its
analytical spine.

---

## What we did

**HHI change (2019 to 2025)**
Joined hhi_by_year to itself on material name to get 2019 and 2025 HHI side by
side, then subtracted to get the change. Reserved word fix: renamed the alias
from `change` to `hhi_change` to avoid MySQL error 1064.

**Price volatility (CoV)**
Used STDDEV_SAMP (sample standard deviation, divides by n-1) divided by AVG on
crm_prices, grouped by material. STDDEV_SAMP is correct here because our seven
yearly prices are a sample of the broader price distribution, not the full
population.

**Price trend series**
Pulled the full year-by-year price series from crm_prices ordered by material
and year, ready for Power BI visualisation.

---

## What we got

| Material           | HHI 2019 | HHI 2025 | HHI change | Price CoV |
|--------------------|----------|----------|------------|-----------|
| Natural graphite   | 1421     | 2465     | +1044      | 0.185     |
| Copper             | 957      | 1284     | +327       | 0.192     |
| Magnesium          | 8843     | 8582     | -261       | 0.377     |
| Gallium            | 6998     | 6043     | -955       | 0.335     |
| Lithium carbonate  | 6360     | 5081     | -1279      | 0.600     |

---

## Key observations

- Natural graphite is the only material where supply concentration is actively
  worsening, up 1044 HHI points since 2019.
- Lithium carbonate has the most volatile price of the five (CoV 0.600), more
  than three times graphite's 0.185, driven by the EV demand spike in 2022-2023
  and the subsequent correction.
- Gallium's price series shows a structural break from 2022, consistent with
  China's export restriction announcements. CoV alone understates this risk
  because the step-change is directional, not random noise.
- Magnesium spiked in 2022 partly due to the European energy crisis hitting
  smelting costs, then reverted.

---
