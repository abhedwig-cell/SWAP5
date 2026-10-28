// Run in the supported Artifact Tool runtime. Produces an authored intermediate;
// the preservation adapter then merges the targeted edits into the source package.
import fs from 'node:fs/promises';
import path from 'node:path';
import {FileBlob,SpreadsheetFile} from '@oai/artifact-tool';
const [input,authoredOutput,changeFile]=process.argv.slice(2);
if(!input||!authoredOutput||!changeFile)throw new Error('Usage: update_product_database.mjs INPUT.xlsx AUTHORED.xlsx CHANGES.json');
const workbook=await SpreadsheetFile.importXlsx(await FileBlob.load(input));
const changes=JSON.parse(await fs.readFile(changeFile,'utf8'));
const sheet=workbook.worksheets.getItem(changes.sheet);
for(const {cell,value} of changes.changes)sheet.getRange(cell).values=[[value]];
sheet.getRange('A2:R5').format.wrapText=true;
sheet.getRange('A2:R5').format.verticalAlignment='top';
sheet.getRange('A2:R5').format.rowHeight=112;
workbook.recalculate();
console.log((await workbook.inspect({kind:'table',range:'Kalmthoutseheide!N2:R5',include:'values,formulas',tableMaxRows:4,tableMaxCols:5,maxChars:5000})).ndjson);
await fs.mkdir(path.dirname(authoredOutput),{recursive:true});
const xlsx=await SpreadsheetFile.exportXlsx(workbook);await xlsx.save(authoredOutput);
