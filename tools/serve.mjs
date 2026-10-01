#!/usr/bin/env node
// 本機靜態預覽。只把 dist/ 的檔案送出去，沒有任何後端邏輯，也不是部署目標。
// 用法：node tools/serve.mjs [dist] [port]

import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const siteDir = path.resolve(root, process.argv[2] ?? "dist");
const port = Number(process.argv[3] ?? 4173);

const types = {
	".html": "text/html; charset=utf-8",
	".css": "text/css; charset=utf-8",
	".js": "text/javascript; charset=utf-8",
	".mjs": "text/javascript; charset=utf-8",
	".json": "application/json; charset=utf-8",
	".svg": "image/svg+xml",
	".png": "image/png",
	".jpg": "image/jpeg",
	".jpeg": "image/jpeg",
	".webp": "image/webp",
	".pdf": "application/pdf",
	".xml": "application/xml; charset=utf-8",
	".txt": "text/plain; charset=utf-8",
	".typ": "text/plain; charset=utf-8",
	".md": "text/plain; charset=utf-8",
	".woff2": "font/woff2",
};

async function resolveFile(urlPath) {
	const decoded = decodeURIComponent(urlPath.split("?")[0].split("#")[0]);
	const candidate = path.join(siteDir, path.normalize(decoded).replace(/^([/\\])+/, ""));
	if (!candidate.startsWith(siteDir)) {
		return null;
	}
	try {
		const info = await stat(candidate);
		if (info.isDirectory()) {
			return path.join(candidate, "index.html");
		}
		return candidate;
	} catch {
		return null;
	}
}

createServer(async (request, response) => {
	let file = await resolveFile(request.url ?? "/");
	if (!file) {
		file = path.join(siteDir, "404.html");
		response.statusCode = 404;
	}
	try {
		const data = await readFile(file);
		response.setHeader("content-type", types[path.extname(file).toLowerCase()] ?? "application/octet-stream");
		response.end(data);
	} catch {
		response.statusCode = 404;
		response.end("not found");
	}
}).listen(port, "127.0.0.1", () => {
	console.log(`local preview: http://127.0.0.1:${port}/  (serving ${path.relative(root, siteDir)})`);
});