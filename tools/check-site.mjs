#!/usr/bin/env node
// 站點自查：對 dist/ 的產出做結構檢查，有問題就以非零退出碼結束。
//
// 這支腳本只讀 dist/，不讀原始碼，故檢查的是瀏覽器與爬蟲真正看到的東西。
// 由 package.json 的 build 指令在產生器之後呼叫，CI 因此會在產出壞掉時停止部署。
//
// 檢查項：
//   1. 站內連結（href／src 以 / 開頭）都能對到 dist/ 裡的檔案或目錄首頁。
//   2. 同一頁的 id 不重複，且每個 #錨點都對得到該頁的 id。
//   3. 每頁都有 lang、title、canonical，且只有一個 h1。
//   4. 每頁都出現在 sitemap.xml。

import { readFile, readdir, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outDir = path.join(root, process.argv[2] ?? "dist");

// 正文片段是給產生器組頁面用的素材，不是要給人看的頁面；
// 它被 vite 原樣複製進 dist/，故自查時要排除在頁面之外，但仍可作為連結目標。
const fragmentPattern = /(^|\/)body\.html$/;

async function walk(directory) {
	const entries = await readdir(directory, { withFileTypes: true });
	const files = [];
	for (const entry of entries) {
		const full = path.join(directory, entry.name);
		if (entry.isDirectory()) {
			files.push(...await walk(full));
		}
		else if (entry.isFile()) {
			files.push(full);
		}
	}
	return files;
}

function relative(file) {
	return path.relative(outDir, file).split(path.sep).join("/");
}

// 站內網址可能指向目錄（伺服器會回 index.html），故兩種都要試。
async function resolves(urlPath) {
	const clean = decodeURIComponent(urlPath.replace(/^\/+/, ""));
	const candidates = [path.join(outDir, clean), path.join(outDir, clean, "index.html")];
	for (const candidate of candidates) {
		try {
			const info = await stat(candidate);
			if (info.isFile()) {
				return true;
			}
		}
		catch {
			// 不存在就是不存在，繼續試下一個候選。
		}
	}
	return false;
}

const allFiles = await walk(outDir);
const htmlFiles = allFiles.filter((file) => file.endsWith(".html") && !fragmentPattern.test(relative(file)));
const pages = htmlFiles.map(relative).sort();
// 404 要檢查連結與標題，但它是錯誤頁，不該出現在 sitemap 裡。
const sitemapPages = pages.filter((page) => page !== "404.html");

const problems = [];
const clientRenderedPages = [];
let linkCount = 0;
let anchorCount = 0;

for (const page of pages) {
	const html = await readFile(path.join(outDir, page), "utf8");

	for (const match of html.matchAll(/(?:href|src)="(\/[^"#?]*)"/g)) {
		linkCount += 1;
		if (!await resolves(match[1])) {
			problems.push(`${page}：站內連結指不到檔案 ${match[1]}`);
		}
	}

	const ids = [...html.matchAll(/\sid="([^"]+)"/g)].map((match) => match[1]);
	const duplicated = ids.filter((id, index) => ids.indexOf(id) !== index);
	if (duplicated.length > 0) {
		problems.push(`${page}：id 重複 ${[...new Set(duplicated)].join("、")}`);
	}
	for (const match of html.matchAll(/href="#([^"]+)"/g)) {
		anchorCount += 1;
		if (!ids.includes(match[1])) {
			problems.push(`${page}：錨點 #${match[1]} 在本頁沒有對應的 id`);
		}
	}

	const lang = html.match(/<html lang="([^"]+)"/);
	const title = html.match(/<title>([^<]*)<\/title>/);
	const canonical = html.match(/<link rel="canonical" href="([^"]+)"/);
	const h1Count = (html.match(/<h1[\s>]/g) ?? []).length;
	// clean-disk 那兩頁是 Vue 掛載的，h1 由瀏覽器執行後才出現；
	// 靜態檔案裡本來就沒有，故只對它們放寬 h1 這一條，其餘照查。
	const clientRendered = html.includes('id="app"');
	if (clientRendered) {
		clientRenderedPages.push(page);
	}
	if (!lang) {
		problems.push(`${page}：html 標籤缺 lang`);
	}
	if (!title || title[1].trim().length === 0) {
		problems.push(`${page}：缺 title`);
	}
	if (!canonical) {
		problems.push(`${page}：缺 canonical`);
	}
	if (!clientRendered && h1Count !== 1) {
		problems.push(`${page}：h1 有 ${h1Count} 個，應為 1 個`);
	}
}

// sitemap 要把每一頁都列進去，否則搜尋引擎只知道一部分。
const sitemapPath = path.join(outDir, "sitemap.xml");
let sitemapMissing = [];
try {
	const sitemap = await readFile(sitemapPath, "utf8");
	const locations = new Set([...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => match[1]));
	sitemapMissing = sitemapPages.filter((page) => !locations.has(`https://tsinswreng.github.io/${page.replace(/index\.html$/, "")}`));
	if (locations.has("https://tsinswreng.github.io/404.html")) {
		problems.push("sitemap.xml 不該收錄 404.html");
	}
}
catch {
	problems.push("缺 sitemap.xml");
}
for (const page of sitemapMissing) {
	problems.push(`sitemap.xml 少了 ${page}`);
}

if (problems.length > 0) {
	console.error(`check-site: ${problems.length} 個問題`);
	for (const problem of problems) {
		console.error(`  - ${problem}`);
	}
	process.exit(1);
}

console.log(`check-site: 頁面 ${pages.length} 個、站內連結 ${linkCount} 條、錨點 ${anchorCount} 個，全部通過。`);
if (clientRenderedPages.length > 0) {
	console.log(`check-site: 純前端渲染故不查 h1 的頁面：${clientRenderedPages.join("、")}`);
}