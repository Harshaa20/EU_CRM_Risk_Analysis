SELECT h.material,
       h.hhi AS hhi_2025,
       h.hhi - h2.hhi AS hhi_change,
       ROUND(STDDEV_SAMP(p.import_price_eur_per_kg) / AVG(p.import_price_eur_per_kg), 3) AS price_cov
FROM hhi_by_year h
JOIN hhi_by_year h2 ON h.material = h2.material AND h2.year = 2019
JOIN crm_prices p ON h.material = p.material
WHERE h.year = 2025
GROUP BY h.material, h.hhi, h2.hhi
ORDER BY h.material;



SELECT material, hhi_2025, hhi_change, price_cov,
       ROUND((hhi_2025_rank + hhi_change_rank + price_cov_rank) / 3, 2) AS avg_risk_rank
FROM (
    SELECT material, hhi_2025, hhi_change, price_cov,
           (SELECT COUNT(*) FROM (
               SELECT h.material, h.hhi AS hhi_2025
               FROM hhi_by_year h WHERE h.year = 2025
           ) t2 WHERE t2.hhi_2025 <= s.hhi_2025) AS hhi_2025_rank,
           (SELECT COUNT(*) FROM (
               SELECT h.material, h.hhi - h2.hhi AS hhi_change
               FROM hhi_by_year h JOIN hhi_by_year h2 ON h.material = h2.material AND h2.year = 2019
               WHERE h.year = 2025
           ) t3 WHERE t3.hhi_change <= s.hhi_change) AS hhi_change_rank,
           (SELECT COUNT(*) FROM (
               SELECT material, ROUND(STDDEV_SAMP(import_price_eur_per_kg) / AVG(import_price_eur_per_kg), 3) AS price_cov
               FROM crm_prices GROUP BY material
           ) t4 WHERE t4.price_cov <= s.price_cov) AS price_cov_rank
    FROM (
        SELECT h.material,
               h.hhi AS hhi_2025,
               h.hhi - h2.hhi AS hhi_change,
               ROUND(STDDEV_SAMP(p.import_price_eur_per_kg) / AVG(p.import_price_eur_per_kg), 3) AS price_cov
        FROM hhi_by_year h
        JOIN hhi_by_year h2 ON h.material = h2.material AND h2.year = 2019
        JOIN crm_prices p ON h.material = p.material
        WHERE h.year = 2025
        GROUP BY h.material, h.hhi, h2.hhi
    ) s
) ranked
ORDER BY avg_risk_rank DESC;



# Phase 4: Composite Risk Ranking

## Why we did this

The three risk dimensions from Phases 2 and 3 live on incompatible scales.
HHI 2025 runs into the thousands. HHI change can be positive or negative.
CoV sits between 0 and 1. Comparing them directly is meaningless.

Phase 4 converts each dimension into a rank from 1 (lowest risk) to 5
(highest risk), then averages the three ranks into one composite score per
material. No weights, no assumptions about which dimension matters more.
The result is a single, defensible number that lets a decision-maker
immediately see which materials deserve priority attention.

---

## What we did

Built the summary table by joining hhi_by_year to itself (2025 vs 2019)
and joining crm_prices to get all three dimensions in one row per material.

Ranked each dimension using correlated subqueries: for each material, count
how many materials score lower or equal on that dimension. This gives a
rank from 1 to 5 without window functions.

Averaged the three ranks and ordered by composite score descending.

---

## What we got

| Material           | HHI 2025 | HHI change | Price CoV | Avg risk rank |
|--------------------|----------|------------|-----------|---------------|
| Magnesium          | 8582     | -261       | 0.377     | 4.00          |
| Gallium            | 6043     | -955       | 0.335     | 3.00          |
| Lithium carbonate  | 5081     | -1279      | 0.600     | 3.00          |
| Natural graphite   | 2465     | +1044      | 0.185     | 2.67          |
| Copper             | 1284     | +327       | 0.192     | 2.33          |

---

## Key observations

- Magnesium ranks highest not because it deteriorated, but because its
  starting concentration (HHI 8582) is so extreme that even a slight
  improvement leaves it far above everything else. China supplies over
  92% of EU magnesium imports as of 2025.
- Gallium and lithium carbonate tie at 3.00 for opposite reasons. Gallium
  is highly concentrated but slowly diversifying. Lithium is diversifying
  rapidly but carries the most price volatility of the five materials,
  CoV 0.600, driven by the 2022-2023 EV demand spike and subsequent
  correction.
- Natural graphite is the quiet risk. Its composite score is mid-table,
  but it is the only material where supply concentration is actively
  worsening year on year. The ranking does not fully capture that
  directional trend.
- Copper is the most manageable of the five: lowest concentration, modest
  price volatility, and a deep global market with many established
  suppliers.

---

## Limitation

The ranking is unweighted. A supply-chain practitioner might reasonably
argue that 2025 HHI deserves more weight than HHI change, or that price
volatility matters less for materials bought under long-term contracts.
The composite score is a starting point for that conversation, not a
final verdict.

---