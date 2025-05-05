#!/usr/bin/env node
const fs = require("fs");
const ALLOWED_DOMAINS = ["api.github.com","api.sendgrid.com","api.line.me","localhost"];
const files = process.argv.slice(2);
let hasError = false;
if(files.length === 0){console.error("Error: Please provide at least one JSON file path");process.exit(1);}
files.forEach(file => {
  try {
    const fileContent = fs.readFileSync(file, "utf8");
    let data;
    try {
      data = JSON.parse(fileContent);
    } catch (jsonError) {
      console.error(`Error: Cannot parse ${file}: ${jsonError.message}`);
      hasError = true;
      return;
    }
    const nodes = data.nodes || [];
    if (!Array.isArray(nodes)) {
      console.error(`Error: ${file} is not a valid n8n workflow (nodes array not found)`);
      hasError = true;
      return;
    }
    nodes.forEach(node => {
      if (!node || typeof node !== "object" || !node.type) return;
      if (node.type === "n8n-nodes-base.executeCommand") {
        console.error(`Error (Security): ${file} node "${node.name || "unnamed"}" uses forbidden ExecuteCommand`);
        hasError = true;
      }
      if ((node.type === "n8n-nodes-base.httpRequest" || node.type === "HttpRequest") && node.parameters && node.parameters.url) {
        try {
          const urlString = node.parameters.url.trim();
          const urlWithProtocol = urlString.match(/^https?:\/\//) ? urlString : `https://${urlString}`;
          const hostname = new URL(urlWithProtocol).hostname;
          if (!ALLOWED_DOMAINS.includes(hostname)) {
            console.error(`Error (Security): ${file} node "${node.name || "unnamed"}" uses non-whitelisted domain "${hostname}"`);
            hasError = true;
          }
        } catch (urlError) {
          console.error(`Error: Cannot parse URL in ${file} node "${node.name || "unnamed"}": ${urlError.message}`);
          hasError = true;
        }
      }
      const sensitiveNodeTypes = ["n8n-nodes-base.ssh","n8n-nodes-base.webhook"];
      if (sensitiveNodeTypes.includes(node.type)) {
        console.warn(`Warning: ${file} uses potentially sensitive node type "${node.type}" (node: "${node.name || "unnamed"}")`);
      }
    });
  } catch (error) {
    console.error(`Error processing ${file}: ${error.message}`);
    hasError = true;
  }
});
if (hasError) {
  console.error("Validation failed: Please fix the errors above");
  process.exit(1);
} else {
  console.log("✅ Custom validation passed");
  process.exit(0);
}
