const fs = require("fs");
const path = require("path");
const pdfParse = require("pdf-parse");

const SECTIONS = {
  4.1: "Therapeutic indications",
  4.2: "Posology and method of administration",
  4.3: "Contraindications",
  4.4: "Special warnings and precautions for use",
  4.5: "Interactions with other medicinal products",
  4.6: "Fertility, pregnancy and lactation",
  4.7: "Effects on ability to drive and use machines",
  4.8: "Undesirable effects",
  4.9: "Overdose",
  6.2: "Incompatibilities",
};

async function extractSectionsFromPDF(pdfPath) {
  const dataBuffer = fs.readFileSync(pdfPath);
  const data = await pdfParse(dataBuffer);
  const text = data.text;

  const extracted = {};
  const sectionKeys = Object.keys(SECTIONS);
  const pattern = new RegExp(`(?:^|\\n)(\\d\\.\\d)\\s+([^\\n]*)`, "g");

  const matches = [];
  let match;
  while ((match = pattern.exec(text)) !== null) {
    matches.push({ code: match[1], title: match[2], index: match.index });
  }

  for (let i = 0; i < matches.length; i++) {
    const current = matches[i];
    const next = matches[i + 1];
    if (sectionKeys.includes(current.code)) {
      const sectionStart = current.index;
      const sectionEnd = next ? next.index : text.length;
      const content = text.substring(sectionStart, sectionEnd).trim();
      extracted[`${current.code} ${SECTIONS[current.code]}`] = content;
    }
  }

  return extracted;
}

async function processAllPDFs() {
  const pdfDir = path.join(__dirname, "pdfs");
  const outputDir = path.join(__dirname, "output");

  // Ensure output directory exists
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir);
  }

  const files = fs.readdirSync(pdfDir).filter((f) => f.endsWith(".pdf"));

  for (const file of files) {
    const fullPath = path.join(pdfDir, file);
    try {
      console.log(`Processing: ${file}`);
      const sections = await extractSectionsFromPDF(fullPath);

      // Save output JSON for each PDF
      const outputFilePath = path.join(
        outputDir,
        file.replace(".pdf", ".json")
      );
      fs.writeFileSync(
        outputFilePath,
        JSON.stringify(sections, null, 2),
        "utf-8"
      );

      console.log(`✔ Saved: ${outputFilePath}`);
    } catch (err) {
      console.error(`❌ Failed to process ${file}:`, err.message);
    }
  }

  console.log("✅ All PDFs processed.");
}

processAllPDFs();
