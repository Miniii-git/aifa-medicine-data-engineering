const fs = require("fs");
const path = require("path");
const Papa = require("papaparse");
const axios = require("axios");

const inputCsv = "filtered_dataset_A_original.csv";
const outputCsv = "filtered_dataset_A_last.csv";

const headers = {
  "User-Agent": "Mozilla/5.0",
  Accept: "application/json",
};

async function getCodiceSis(aic) {
  const paddedAIC = aic.toString().padStart(9, "0");
  const url = `https://api.aifa.gov.it/aifa-bdf-eif-be/1.0.0/formadosaggio/ricerca?query=${paddedAIC}&spellingCorrection=true&page=0`;

  try {
    const response = await axios.get(url, { headers });
    const data = response.data;

    const medicinale = data?.data?.content?.[0]?.medicinale;
    if (!medicinale || !medicinale.codiceSis) {
      console.warn(`⚠️ codiceSis not found for AIC ${aic}`);
      return null;
    }

    return {
      codiceSis: medicinale.codiceSis,
      paddedAIC,
    };
  } catch (err) {
    console.warn(`❌ Error fetching codiceSis for AIC ${aic}: ${err.message}`);
    return null;
  }
}

async function main() {
  // Load and parse CSV
  const raw = fs.readFileSync(inputCsv, "utf8");
  const parsed = Papa.parse(raw, {
    header: true,
    transformHeader: (h) => h.trim(),
  });

  const rows = parsed.data;
  const enrichedRows = [];

  for (const row of rows) {
    const aic = row["AIC"] || row["aic"] || row["Aic"];
    if (!aic) {
      console.warn(`⚠️ Skipping row due to missing AIC:`, row);
      continue;
    }

    const result = await getCodiceSis(aic);
    if (!result || !result.codiceSis) continue;

    const codiceSisClean = parseInt(result.codiceSis).toString();
    const aicTrimmed = result.paddedAIC.slice(1, 6);
    const url = `https://api.aifa.gov.it/aifa-bdf-eif-be/1.0.0/organizzazione/${codiceSisClean}/farmaci/${aicTrimmed}/stampati?ts=RCP`;

    enrichedRows.push({
      ...row,
      AIC: result.paddedAIC,
      codiceSis: result.codiceSis,
      URL: url,
    });
  }

  // Save result to CSV
  const csv = Papa.unparse(enrichedRows);
  fs.writeFileSync(outputCsv, csv);
  console.log(
    `✅ Saved enriched dataset to "${outputCsv}" with ${enrichedRows.length} rows`
  );
}

main();
