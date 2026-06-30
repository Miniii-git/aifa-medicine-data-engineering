const fs = require("fs");
const path = require("path");
const csv = require("csv-parser");
const createCsvWriter = require("csv-writer").createObjectCsvWriter;

const inputCsvPath = path.join(__dirname, "filtered_dataset_A_last.csv");
const jsonOutputDir = path.join(__dirname, "output");
const enrichedCsvPath = path.join(__dirname, "enriched_dataset.csv");

// Sections to extract
const sectionKeys = [
  "4.1 Therapeutic indications",
  "4.2 Posology and method of administration",
  "4.3 Contraindications",
  "4.4 Special warnings and precautions for use",
  "4.5 Interactions with other medicinal products",
  "4.6 Fertility, pregnancy and lactation",
  "4.7 Effects on ability to drive and use machines",
  "4.8 Undesirable effects",
  "4.9 Overdose",
  "6.2 Incompatibilities",
];

function readCSVWithAIC(csvPath) {
  return new Promise((resolve, reject) => {
    const rows = [];
    fs.createReadStream(csvPath)
      .pipe(csv())
      .on("data", (data) => rows.push(data))
      .on("end", () => resolve(rows))
      .on("error", reject);
  });
}

async function enrichCSV() {
  const rows = await readCSVWithAIC(inputCsvPath);

  const headers = Object.keys(rows[0]).map((key) => ({ id: key, title: key }));
  sectionKeys.forEach((key) => headers.push({ id: key, title: key }));

  const csvWriter = createCsvWriter({
    path: enrichedCsvPath,
    header: headers,
  });

  const enrichedRows = rows.map((row) => {
    const enriched = { ...row };
    const aic = row["AIC"];

    try {
      const jsonFile = fs
        .readdirSync(jsonOutputDir)
        .find((f) => f.endsWith(`${aic}.json`));

      if (jsonFile) {
        const jsonPath = path.join(jsonOutputDir, jsonFile);
        const extractedData = JSON.parse(fs.readFileSync(jsonPath, "utf-8"));

        sectionKeys.forEach((key) => {
          enriched[key] = extractedData[key]?.trim() || "NOT Available";
        });
      } else {
        console.warn(`⚠ No JSON found for AIC: ${aic}`);
        sectionKeys.forEach((key) => {
          enriched[key] = "NOT Available";
        });
      }
    } catch (err) {
      console.error(`❌ Error processing AIC ${aic}:`, err.message);
      sectionKeys.forEach((key) => {
        enriched[key] = "NOT Available";
      });
    }

    return enriched;
  });

  await csvWriter.writeRecords(enrichedRows);
  console.log(`✅ Enriched CSV saved to: ${enrichedCsvPath}`);
}

enrichCSV().catch((err) => console.error("Error enriching CSV:", err));
