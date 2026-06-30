const axios = require("axios");
const fs = require("fs");
const path = require("path");
const csv = require("csv-parser");

const csvFilePath = "./filtered_dataset_A_last.csv"; // CSV file in the same directory
const downloadDir = "./pdfs";

// Create download folder if it doesn't exist
if (!fs.existsSync(downloadDir)) {
  fs.mkdirSync(downloadDir);
}

// Helper function to download a PDF
async function downloadPDF(url, aic) {
  const safeAIC = aic.replace(/[^a-zA-Z0-9]/g, "_"); // Sanitize filename
  const filename = `${safeAIC}.pdf`;
  const filePath = path.join(downloadDir, filename);

  try {
    const response = await axios.get(url, {
      responseType: "stream",
      headers: {
        "User-Agent": "Mozilla/5.0",
        Accept: "*/*", // Accept any file type
        Connection: "keep-alive",
      },
      validateStatus: () => true,
    });

    if (response.status === 200) {
      const writer = fs.createWriteStream(filePath);
      response.data.pipe(writer);
      writer.on("finish", () => console.log(`✅ Saved: ${filename}`));
      writer.on("error", (err) =>
        console.error(`❌ Write error for ${filename}:`, err)
      );
    } else {
      console.error(
        `❌ Failed to download ${filename}: Status ${response.status}`
      );
    }
  } catch (err) {
    console.error(`❌ Axios error for ${filename}: ${err.message}`);
  }
}

// Read the CSV and process each row
fs.createReadStream(csvFilePath)
  .pipe(csv())
  .on("data", (row) => {
    const aic = row["AIC"];
    const url = row["URL"]; // ✅ Use correct case

    if (url && aic) {
      downloadPDF(url, aic);
    } else {
      console.warn("⚠️ Missing AIC or URL in row:", row);
    }
  })
  .on("end", () => {
    console.log("✅ All rows processed");
  })
  .on("error", (err) => {
    console.error("❌ CSV Read error:", err);
  });
