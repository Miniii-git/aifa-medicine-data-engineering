-- 1. Principi Attivi
CREATE TABLE principi_attivi (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `Principio Attivo` VARCHAR(100) UNIQUE
);

INSERT INTO principi_attivi (`Principio Attivo`)
SELECT DISTINCT `Principio Attivo` FROM enriched_datasetn
WHERE `Principio Attivo` IS NOT NULL;

-- 2. Descrizioni Gruppo
CREATE TABLE descrizioni_gruppi (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `Descrizione Gruppo` VARCHAR(150) UNIQUE,
    `Codice Gruppo Equivalenza` VARCHAR(10)
);

INSERT INTO descrizioni_gruppi (`Descrizione Gruppo`, `Codice Gruppo Equivalenza`)
SELECT DISTINCT `Descrizione Gruppo`, `Codice Gruppo Equivalenza`
FROM enriched_datasetn
WHERE `Descrizione Gruppo` IS NOT NULL;

-- 3. Titolari AIC
CREATE TABLE titolari_aic (
    id INT AUTO_INCREMENT PRIMARY KEY,
    `Titolare AIC` VARCHAR(150) UNIQUE
);

INSERT INTO titolari_aic (`Titolare AIC`)
SELECT DISTINCT `Titolare AIC` FROM enriched_datasetn
WHERE `Titolare AIC` IS NOT NULL;

-- 4. Medicinali (core table)
CREATE TABLE medicinali (
    AIC BIGINT PRIMARY KEY,
    `Denominazione e Confezione` VARCHAR(150),
    codiceSis INT,
    url TEXT,
    principio_attivo_id INT,
    descrizione_gruppo_id INT,
    titolare_aic_id INT,
    FOREIGN KEY (principio_attivo_id) REFERENCES principi_attivi(id),
    FOREIGN KEY (descrizione_gruppo_id) REFERENCES descrizioni_gruppi(id),
    FOREIGN KEY (titolare_aic_id) REFERENCES titolari_aic(id)
);

INSERT INTO medicinali (
    AIC, `Denominazione e Confezione`, codiceSis, url,
    principio_attivo_id, descrizione_gruppo_id, titolare_aic_id
)
SELECT 
    e.AIC,
    e.`Denominazione e Confezione`,
    e.codiceSis,
    e.URL,
    (SELECT id FROM principi_attivi WHERE `Principio Attivo` = e.`Principio Attivo`),
    (SELECT id FROM descrizioni_gruppi WHERE `Descrizione Gruppo` = e.`Descrizione Gruppo`),
    (SELECT id FROM titolari_aic WHERE `Titolare AIC` = e.`Titolare AIC`)
FROM enriched_datasetn e;

-- 5. RCP Sezioni (flattened clinical content)
CREATE TABLE rcp_sezioni (
    id INT AUTO_INCREMENT PRIMARY KEY,
    AIC BIGINT,
    sezione VARCHAR(100),
    contenuto TEXT,
    FOREIGN KEY (AIC) REFERENCES medicinali(AIC)
);

-- Insert all relevant sections (for each AIC)

-- Section 4.1
INSERT INTO rcp_sezioni (AIC, sezione, contenuto)
SELECT AIC, '4.1 Therapeutic indications', `4.1 Therapeutic indications`
FROM enriched_datasetn WHERE `4.1 Therapeutic indications` IS NOT NULL;

-- Section 4.2
INSERT INTO rcp_sezioni (AIC, sezione, contenuto)
SELECT AIC, '4.2 Posology and method of administration', `4.2 Posology and method of administration`
FROM enriched_datasetn WHERE `4.2 Posology and method of administration` IS NOT NULL;

-- Section 4.3
INSERT INTO rcp_sezioni (AIC, sezione, contenuto)
SELECT AIC, '4.3 Contraindications', `4.3 Contraindications`
FROM enriched_datasetn WHERE `4.3 Contraindications` IS NOT NULL;

-- Section 4.4
INSERT INTO rcp_sezioni (AIC, sezione, contenuto)
SELECT AIC, '4.4 Special warnings and precautions for use', `4.4 Special warnings and precautions for use`
FROM enriched_datasetn WHERE `4.4 Special warnings and precautions for use` IS NOT NULL;

-- Repeat for all other sections (4.5 to 6.2)

INSERT INTO rcp_sezioni (AIC, sezione, contenuto)
SELECT AIC, '4.5 Interactions with other medicinal products', `4.5 Interactions with other medicinal products`
FROM enriched_datasetn WHERE `4.5 Interactions with other medicinal products` IS NOT NULL;

INSERT INTO rcp_sezioni (AIC, sezione, contenuto)
SELECT AIC, '4.6 Fertility, pregnancy and lactation', `4.6 Fertility, pregnancy and lactation`
FROM enriched_datasetn WHERE `4.6 Fertility, pregnancy and lactation` IS NOT NULL;

INSERT INTO rcp_sezioni (AIC, sezione, contenuto)
SELECT AIC, '4.7 Effects on ability to drive and use machines', `4.7 Effects on ability to drive and use machines`
FROM enriched_datasetn WHERE `4.7 Effects on ability to drive and use machines` IS NOT NULL;

INSERT INTO rcp_sezioni (AIC, sezione, contenuto)
SELECT AIC, '4.8 Undesirable effects', `4.8 Undesirable effects`
FROM enriched_datasetn WHERE `4.8 Undesirable effects` IS NOT NULL;

INSERT INTO rcp_sezioni (AIC, sezione, contenuto)
SELECT AIC, '4.9 Overdose', `4.9 Overdose`
FROM enriched_datasetn WHERE `4.9 Overdose` IS NOT NULL;

INSERT INTO rcp_sezioni (AIC, sezione, contenuto)
SELECT AIC, '6.2 Incompatibilities', `6.2 Incompatibilities`
FROM enriched_datasetn WHERE `6.2 Incompatibilities` IS NOT NULL;

-- query1 ------------------------------------------------------
-- Top 10 Most Common Active Ingredients

SELECT pa.`Principio Attivo`, COUNT(*) AS total_products
FROM medicinali m
JOIN principi_attivi pa ON m.principio_attivo_id = pa.id
GROUP BY pa.`Principio Attivo`
ORDER BY total_products DESC
LIMIT 10;

-- query2 ----------------------------------------------------------
-- List All Products That Have Overdose Information 

SELECT m.`Denominazione e Confezione`, r.contenuto
FROM medicinali m
JOIN rcp_sezioni r ON m.AIC = r.AIC
WHERE r.sezione = '4.9 Overdose';

-- query3 ----------------------------------------------------------
-- therapeutic indication frequency

SELECT 
    r.contenuto AS therapeutic_indication,
    COUNT(*) AS frequency
FROM rcp_sezioni r
WHERE r.sezione = '4.1 Therapeutic indications'
GROUP BY r.contenuto
ORDER BY frequency DESC;


-- query4 ----------------------------------------------------------
-- Side Effects 

SELECT 
    effetto_collaterale AS side_effect,
    COUNT(*) AS frequency
FROM (
    SELECT 
        CASE 
            WHEN LOWER(r.contenuto) LIKE '%nausea%' THEN 'nausea'
            WHEN LOWER(r.contenuto) LIKE '%cefalea%' THEN 'cefalea'
            WHEN LOWER(r.contenuto) LIKE '%capogiri%' THEN 'capogiri'
            WHEN LOWER(r.contenuto) LIKE '%vomito%' THEN 'vomito'
            WHEN LOWER(r.contenuto) LIKE '%diarrea%' THEN 'diarrea'
            WHEN LOWER(r.contenuto) LIKE '%rash%' THEN 'rash cutaneo'
            WHEN LOWER(r.contenuto) LIKE '%sonnolenza%' THEN 'sonnolenza'
        END AS effetto_collaterale
    FROM rcp_sezioni r
    WHERE r.sezione = '4.8 Undesirable effects'
    ) AS effetti
WHERE effetto_collaterale IS NOT NULL
GROUP BY effetto_collaterale
ORDER BY frequency DESC;

-- query5 ----------------------------------------------------------
-- Products by Side Effect Mentioned

SELECT
    m.`Denominazione e Confezione` AS prodotto,
    CASE
        WHEN LOWER(r.contenuto) LIKE '%nausea%' THEN 'nausea'
        WHEN LOWER(r.contenuto) LIKE '%cefalea%' THEN 'cefalea'
        WHEN LOWER(r.contenuto) LIKE '%capogiri%' THEN 'capogiri'
        WHEN LOWER(r.contenuto) LIKE '%vomito%' THEN 'vomito'
        WHEN LOWER(r.contenuto) LIKE '%diarrea%' THEN 'diarrea'
        WHEN LOWER(r.contenuto) LIKE '%rash%' THEN 'rash cutaneo'
        WHEN LOWER(r.contenuto) LIKE '%sonnolenza%' THEN 'sonnolenza'
    END AS effetto_collaterale
FROM rcp_sezioni r
JOIN medicinali m ON r.AIC = m.AIC
WHERE r.sezione = '4.8 Undesirable effects'
  AND (
        LOWER(r.contenuto) LIKE '%nausea%' OR
        LOWER(r.contenuto) LIKE '%cefalea%' OR
        LOWER(r.contenuto) LIKE '%capogiri%' OR
        LOWER(r.contenuto) LIKE '%vomito%' OR
        LOWER(r.contenuto) LIKE '%diarrea%' OR
        LOWER(r.contenuto) LIKE '%rash%' OR
        LOWER(r.contenuto) LIKE '%sonnolenza%'
      );
      
-- query6 ----------------------------------------------------------
-- Count of Products Per Active Ingredient With Overdose Section

SELECT
    pa.`Principio Attivo`,
    COUNT(DISTINCT m.AIC) AS products_with_overdose_info
FROM principi_attivi pa
JOIN medicinali m ON pa.id = m.principio_attivo_id
JOIN rcp_sezioni r ON m.AIC = r.AIC
WHERE r.sezione = '4.9 Overdose'
GROUP BY pa.`Principio Attivo`
ORDER BY products_with_overdose_info DESC;

-- query7 ----------------------------------------------------------
-- How many products each Titolare AIC holds

SELECT 
    t.`Titolare AIC` AS titolare,
    COUNT(*) AS numero_medicinali
FROM medicinali m
JOIN titolari_aic t ON m.titolare_aic_id = t.id
GROUP BY t.`Titolare AIC`
ORDER BY numero_medicinali DESC;

-- query8 -----------------
-- List of Medicines by a Specific Marketing Authorization Holder (Titolare AIC)

SELECT 
    t.`Titolare AIC`,
    m.`Denominazione e Confezione`,
    p.`Principio Attivo`
FROM medicinali m
JOIN titolari_aic t ON m.titolare_aic_id = t.id
JOIN principi_attivi p ON m.principio_attivo_id = p.id
WHERE t.`Titolare AIC` = 'SANDOZ SpA';  
