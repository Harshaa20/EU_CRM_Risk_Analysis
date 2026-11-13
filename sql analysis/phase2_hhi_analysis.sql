CREATE DATABASE critical_materials CHARACTER SET utf8mb4;

USE critical_materials;

CREATE TABLE supplier_data (
  material VARCHAR(30),
  partner_area VARCHAR(150),
  year INT,
  import_value_eur DECIMAL(18,2)
);


CREATE TABLE crm_prices (
  material VARCHAR(30),
  year INT,
  import_price_eur_per_kg DECIMAL(12,6)
);

SELECT COUNT(*) FROM supplier_data;
SELECT COUNT(*) FROM crm_prices;

# Phase 2, Step 1: Load the data into MySQL

**Question:** Can the Eurostat import data and price data be queried reliably?

**Why:** SQL can only answer what it holds. 
**Numbers must stay numbers and accents must survive, or the shares and totals later will be wrong.

**Checks**
- `SELECT COUNT(*) FROM supplier_data;` returned 1004 (expected 1004)
- `SELECT COUNT(*) FROM crm_prices;` returned 35 (expected 35)

**Result:** Both tables loaded completely. Analysis can start.

**Issues met:** Several statements sent together in DBeaver caused errors.
**Run one query per line with Ctrl+Enter. 
**An earlier setup left a second database, which we removed.

SELECT * FROM supplier_data WHERE partner_area LIKE 'T%rkiye' LIMIT 3;

SELECT SUBSTRING_INDEX(partner_area, ' (', 1) AS country, material, year, COUNT(*) AS n
FROM supplier_data
GROUP BY country, material, year
HAVING COUNT(*) > 1;

SELECT material, year, SUM(import_value_eur) AS total_eur
FROM supplier_data
GROUP BY material, year
ORDER BY material, year;

CREATE TABLE material_totals AS
SELECT material, year, SUM(import_value_eur) AS total_eur
FROM supplier_data
GROUP BY material, year;

SELECT COUNT(*) FROM material_totals;



SELECT SUBSTRING_INDEX(s.partner_area, ' (', 1) AS country,
       ROUND(s.import_value_eur / t.total_eur * 100, 2) AS share_pct
FROM supplier_data s
JOIN material_totals t
  ON s.material = t.material AND s.year = t.year
WHERE s.material = 'Magnesium' AND s.year = 2025
ORDER BY share_pct DESC;



SELECT s.material, s.year,
       ROUND(SUM(POW(s.import_value_eur / t.total_eur * 100, 2))) AS hhi
FROM supplier_data s
JOIN material_totals t
  ON s.material = t.material AND s.year = t.year
WHERE s.year = 2025
GROUP BY s.material, s.year
ORDER BY hhi DESC;


SELECT s.material, s.year,
       ROUND(SUM(POW(s.import_value_eur / t.total_eur * 100, 2))) AS hhi
FROM supplier_data s
JOIN material_totals t
  ON s.material = t.material AND s.year = t.year
GROUP BY s.material, s.year
ORDER BY s.material, s.year;


# Phase 2: From raw imports to supplier concentration (SQL)

**Question:** How concentrated is the EU's supply of each critical raw material, and which countries carry that risk?

**Why it matters:** A material bought from one country is a bigger risk than one spread across many. 
**HHI turns that into a single number per material and year, so the five materials can be compared directly.

## Setup
- Database `critical_materials` with two tables: `supplier_data` (1,004 rows) and `crm_prices` (35 rows).
- Import encoding is UTF-8. Accents such as "Türkiye" survive.
- Country names are cleaned with `SUBSTRING_INDEX`, which removes the Eurostat footnotes in brackets. 
- No two rows merged in the duplicate check.

## What we built
- `material_totals`: total EUR imports per material and year (35 rows).
- Each country's share = its imports / the material's total for that year.
- `hhi_by_year`: sum of squared shares per material and year (35 rows).

## Results
- **Magnesium** is the most concentrated. HHI stayed above 8,300 in every year and reached 9,463 in 2023. 
- China supplied 92.47% in 2025.
- **Gallium** peaked at 9,381 in 2022, fell to 5,034 in 2024, and rose to 6,043 in 2025.
- **Natural graphite** rose from 1,421 (2019) to 3,099 (2024), then 2,465 in 2025.
- **Lithium carbonate** ended 2025 at 5,081, down from 6,360 in 2019.
- **Copper** is the least concentrated, at 1,284 in 2025.
- All 35 HHI values match the answer key.

## Issues met
- Running several statements together in DBeaver caused errors. 
- Run one query per line with Ctrl+Enter.
- An earlier attempt left a second database. 
- We removed it and worked only in `critical_materials`.

## Limitations
- Shares are based on import value in euros, not physical volume.
- Unspecified partners are excluded, which slightly overstates the named countries' shares.
- Copper combines ores and refined metal, so its HHI is a blended figure.