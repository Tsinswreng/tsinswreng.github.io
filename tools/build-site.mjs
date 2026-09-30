#!/usr/bin/env node
// 由 public/articles/catalog.json 生成整個靜態站點。
//
// 執行順序：vite build 先把 public/ 複製進 dist/ 並產出互動頁，本腳本再往 dist/ 寫入所有頁面。
// 本腳本不做 HTML 解析：正文片段（body.html）、標題錨點與目錄都由
// tools/ImportMvnPublish.csx 用 AngleSharp 產生，那裏纔有真正的解析器。
//
// 網址規則見 site.config.mjs 的檔頭註解。

import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
	defaultLocale,
	languageNames,
	localeOrder,
	localePrefix,
	nav,
	openGraphLocales,
	origin,
	stubPages,
	ui,
} from "../site.config.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const publicDir = path.join(root, "public");
const outDir = path.join(root, "dist");
const articlesDir = path.join(publicDir, "articles");

const currentYear = new Date().getFullYear();

function escapeHtml(value) {
	return String(value).replace(/[&<>"']/g, (character) => ({
		"&": "&amp;",
		"<": "&lt;",
		">": "&gt;",
		'"': "&quot;",
		"'": "&#39;",
	})[character]);
}

function text(locale) {
	return ui[locale] ?? ui[defaultLocale];
}

function languageName(code) {
	return languageNames[code] ?? code;
}

// ── 資料 ────────────────────────────────────────────────────

async function readCatalog() {
	const catalogPath = path.join(articlesDir, "catalog.json");
	if (!existsSync(catalogPath)) {
		console.warn(`build-site: 找不到 ${path.relative(root, catalogPath)}，站點將只有站殼頁面。`);
		return [];
	}
	const catalog = JSON.parse(await readFile(catalogPath, "utf8"));
	return catalog.articles ?? [];
}

async function readArticleMeta() {
	// 機器推不出來、需要人寫的欄位（日期、摘要、標籤）放這裏，由腳本與 catalog 合併。
	const metaPath = path.join(root, "articles.meta.json");
	if (!existsSync(metaPath)) {
		return {};
	}
	return JSON.parse(await readFile(metaPath, "utf8"));
}

// 一篇文章的識別：slug（Mvn manifest 的 Slug）＋ 內容語言 ＋ 文檔名（同語言多文檔時纔有）。
function articleKey(article) {
	return [article.slug, article.contentLang, article.doc ?? ""].join("/");
}

function readingPath(article) {
	const prefix = localePrefix(article.contentLang);
	const doc = article.doc ? `${article.doc}/` : "";
	return `${prefix}/articles/${article.slug}/${article.contentLang}/${doc}`;
}

function workPath(locale, slug) {
	return `${localePrefix(locale)}/articles/${slug}/`;
}

function listPath(locale) {
	return `${localePrefix(locale)}/articles/`;
}

function homePath(locale) {
	return `${localePrefix(locale)}/`;
}

function stubPath(locale, key) {
	return `${localePrefix(locale)}/${key}/`;
}

// 頁面在別站臺語言下的對應網址。正文頁只存在於「站臺語言＝內容語言」那一種組合，
// 其餘站臺語言一律退回該篇的入口頁，故不會產生指向不存在頁面的連結。
function logicalPath(logical, locale) {
	switch (logical.kind) {
		case "home":
			return homePath(locale);
		case "articles":
			return listPath(locale);
		case "stub":
			return stubPath(locale, logical.key);
		case "work":
			return workPath(locale, logical.slug);
		case "read":
			return locale === logical.contentLang ? readingPath(logical.article) : workPath(locale, logical.slug);
		default:
			return homePath(locale);
	}
}

// ── 版面 ────────────────────────────────────────────────────

function renderNav(locale, logical) {
	const strings = text(locale);
	const links = nav.map((item) => {
		const current = item.key === logical.navKey ? ' aria-current="page"' : "";
		return `<a href="${logicalPath({ kind: item.key === "home" ? "home" : item.key === "articles" ? "articles" : "stub", key: item.key }, locale)}"${current}>${escapeHtml(strings.nav[item.key])}</a>`;
	}).join("");

	const localeLinks = localeOrder.map((code) => {
		const current = code === locale ? ' aria-current="true"' : "";
		return `<a href="${logicalPath(logical, code)}" hreflang="${code}"${current}>${escapeHtml(languageName(code))}</a>`;
	}).join("");

	return `<nav class="site-nav" aria-label="${escapeHtml(strings.uiLanguage)}">
      <div class="shell site-nav-inner">
        <a class="brand" href="${homePath(locale)}">${escapeHtml(strings.siteName)}</a>
        <div class="nav-links">${links}</div>
        <div class="nav-tools">
          <button class="icon-button" type="button" data-history="back" title="${escapeHtml(strings.back)}" aria-label="${escapeHtml(strings.back)}">&#9664;</button>
          <button class="icon-button" type="button" data-history="forward" title="${escapeHtml(strings.forward)}" aria-label="${escapeHtml(strings.forward)}">&#9654;</button>
          <div class="locale-switch" aria-label="${escapeHtml(strings.uiLanguage)}" lang="${locale}">${localeLinks}</div>
        </div>
      </div>
    </nav>`;
}

function renderFooter(locale) {
	const strings = text(locale);
	return `<footer class="site-footer">
      <p>${escapeHtml(strings.footerNote)}</p>
      <p>&copy; ${currentYear} ${escapeHtml(strings.siteName)}</p>
    </footer>`;
}

// 生成的頁面沒有框架、沒有打包，只有這一段小腳本；
// 它做的事全部是漸進增強：關掉 JS 時頁面仍可讀、連結仍可用。
function inlineScript(strings) {
	const labels = JSON.stringify({
		copy: strings.copy,
		copied: strings.copied,
	}).replace(/</g, "\\u003c");
	return `    <script>
      window.__siteLabels = ${labels};
    </script>
    <script>
      (function () {
        var labels = window.__siteLabels || {};

        document.querySelectorAll("[data-history]").forEach(function (button) {
          button.addEventListener("click", function () {
            if (button.dataset.history === "back") { history.back(); } else { history.forward(); }
          });
        });

        // 目錄高亮：取「最後一個頂端已越過視口上方 20% 的標題」為當前節。
        // 不用 IntersectionObserver，因為它的回呼依賴渲染幀，時序不如直接量位置可控。
        // 只認目錄裡真的有的錨點，故圖表等其他 id 不會干擾。
        var sections = Array.prototype.slice.call(document.querySelectorAll(".toc a[href^='#']"))
          .map(function (link) {
            return { link: link, target: document.getElementById(decodeURIComponent(link.getAttribute("href").slice(1))) };
          })
          .filter(function (item) { return item.target; });
        if (sections.length) {
          var syncToc = function () {
            var line = window.innerHeight * 0.2;
            var current = null;
            sections.forEach(function (item) {
              if (item.target.getBoundingClientRect().top <= line) { current = item; }
            });
            sections.forEach(function (item) {
              item.link.classList.toggle("is-active", item === current);
            });
          };
          window.addEventListener("scroll", syncToc, { passive: true });
          window.addEventListener("resize", syncToc, { passive: true });
          syncToc();
        }

        function copyByFallback(text, done) {
          var area = document.createElement("textarea");
          area.value = text;
          area.setAttribute("readonly", "");
          area.style.position = "fixed";
          area.style.top = "-1000px";
          document.body.appendChild(area);
          area.select();
          try { document.execCommand("copy"); done(); } catch (error) { /* 失敗時原文仍可手動選取 */ }
          document.body.removeChild(area);
        }

        document.querySelectorAll(".article-body pre").forEach(function (pre) {
          // Mvn 的 HTML 靶已經有 .mvn-code-block 外框時直接用它，否則自己包一層。
          var host = pre.closest(".mvn-code-block");
          if (!host) {
            host = document.createElement("div");
            host.className = "code-block";
            pre.parentNode.insertBefore(host, pre);
            host.appendChild(pre);
          }
          var button = document.createElement("button");
          button.type = "button";
          button.className = "copy-button";
          button.textContent = labels.copy || "Copy";
          button.addEventListener("click", function () {
            var done = function () {
              button.textContent = labels.copied || "Copied";
              button.classList.add("is-done");
              setTimeout(function () {
                button.textContent = labels.copy || "Copy";
                button.classList.remove("is-done");
              }, 1600);
            };
            if (navigator.clipboard && window.isSecureContext) {
              navigator.clipboard.writeText(pre.innerText).then(done, function () { copyByFallback(pre.innerText, done); });
            } else {
              copyByFallback(pre.innerText, done);
            }
          });
          host.appendChild(button);
        });

        var toTop = document.querySelector(".to-top");
        if (toTop) {
          var sync = function () {
            toTop.classList.toggle("is-visible", window.scrollY > 600);
          };
          window.addEventListener("scroll", sync, { passive: true });
          sync();
          toTop.addEventListener("click", function () {
            window.scrollTo({ top: 0, behavior: "smooth" });
          });
        }
      })();
    </script>`;
}

function renderPage({ locale, contentLang, logical, navKey, title, description, hero, main, canonicalPath, alternates, publishedTime, tags, toTop }) {
	const pageLocale = contentLang ?? locale;
	const strings = text(locale);
	const documentTitle = title === strings.siteName ? title : `${title}｜${strings.siteName}`;
	const summary = description ?? strings.tagline;
	const canonical = `${origin}${canonicalPath ?? logicalPath(logical, locale)}`;
	const alternateLinks = (alternates ?? [])
		.map((item) => `\n    <link rel="alternate" hreflang="${item.hreflang}" href="${origin}${item.path}">`)
		.join("");
	// 社群平臺與搜尋引擎都靠這幾條；沒有圖檔可放，故不寫 og:image。
	const social = [
		`<meta property="og:site_name" content="${escapeHtml(strings.siteName)}">`,
		`<meta property="og:type" content="${contentLang ? "article" : "website"}">`,
		`<meta property="og:title" content="${escapeHtml(title)}">`,
		`<meta property="og:description" content="${escapeHtml(summary)}">`,
		`<meta property="og:url" content="${canonical}">`,
		`<meta property="og:locale" content="${escapeHtml(openGraphLocales[pageLocale] ?? pageLocale)}">`,
		...alternateLinks
			? (alternates ?? []).filter((item) => openGraphLocales[item.hreflang] && item.hreflang !== pageLocale)
				.map((item) => `<meta property="og:locale:alternate" content="${escapeHtml(openGraphLocales[item.hreflang])}">`)
			: [],
		`<meta name="twitter:card" content="summary">`,
		publishedTime ? `<meta property="article:published_time" content="${escapeHtml(publishedTime)}">` : "",
		...(tags ?? []).map((tag) => `<meta property="article:tag" content="${escapeHtml(tag)}">`),
	].filter(Boolean).join("\n    ");
	const toTopButton = toTop
		? `    <button class="to-top" type="button" title="${escapeHtml(strings.toTop)}" aria-label="${escapeHtml(strings.toTop)}">&#8593;</button>\n`
		: "";

	return `<!doctype html>
<html lang="${pageLocale}">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${escapeHtml(documentTitle)}</title>
    <meta name="description" content="${escapeHtml(summary)}">
    <meta name="author" content="${escapeHtml(strings.siteName)}">
    <link rel="canonical" href="${canonical}">${alternateLinks}
    ${social}
    <link rel="stylesheet" href="/assets/site.css">
    <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Ccircle cx='16' cy='16' r='10' fill='%232fd6d6'/%3E%3C/svg%3E">
    <meta name="theme-color" content="#080a0e">
  </head>
  <body class="page-body">
    ${renderNav(locale, { ...logical, navKey })}
    ${hero ?? ""}
    <main class="site-main">
      <div class="shell">
${main}
      </div>
    </main>
    ${renderFooter(locale)}
${toTopButton}${inlineScript(strings)}
  </body>
</html>
`;
}

function renderHero(locale, { compact, title, subtitle }) {
	const heading = escapeHtml(title ?? text(locale).siteName);
	const line = subtitle ? `<p>${escapeHtml(subtitle)}</p>` : "";
	return `<header class="site-hero${compact ? " site-hero--compact" : ""}">
      <div class="shell">
        <h1>${heading}</h1>
        ${line}
      </div>
    </header>`;
}

// ── 區塊 ────────────────────────────────────────────────────

// 一篇文章的標題依內容語言各自不同，列表要挑當前站臺語言認得的那一個；
// 該篇沒有這個站臺語言的版本時，退回預設內容語言，再退回清單順序第一條。
function preferredArticle(work, locale) {
	return work.articles.find((article) => article.contentLang === locale)
		?? work.articles.find((article) => article.contentLang === defaultLocale)
		?? work.articles[0];
}

function renderArticleItem(locale, work) {
	const strings = text(locale);
	const first = preferredArticle(work, locale);
	const summary = work.meta.summary ? `<p class="summary">${escapeHtml(work.meta.summary)}</p>` : "";
	const date = work.meta.date ? `<span class="badge badge--time">${escapeHtml(work.meta.date)}</span>` : "";
	const languages = work.languages
		.map((code) => `<span class="badge badge--lang">${escapeHtml(languageName(code))}</span>`)
		.join("");
	const note = work.languages.includes(locale) ? "" : `<span class="badge">${escapeHtml(strings.onlyIn(languageName(work.languages[0])))}</span>`;
	return `<a class="article-item" href="${readingPath(first)}">
        <h3>${escapeHtml(first.title)}</h3>
        <div class="meta-row">${languages}${date}${note}</div>
        ${summary}
      </a>`;
}

function renderArticleList(locale, works) {
	const strings = text(locale);
	if (works.length === 0) {
		return `<p class="hint">${escapeHtml(strings.noArticles)}</p>`;
	}
	return `<div class="card-list">${works.map((work) => renderArticleItem(locale, work)).join("\n")}</div>`;
}

function renderToc(locale, toc) {
	const strings = text(locale);
	if (!toc || toc.length === 0) {
		return "";
	}
	const items = toc
		.map((entry) => `<li class="toc-${entry.level}"><a href="#${escapeHtml(entry.id)}">${escapeHtml(entry.text)}</a></li>`)
		.join("\n");
	return `        <aside class="toc">
          <h2>${escapeHtml(strings.toc)}</h2>
          <ol>
${items}
          </ol>
        </aside>`;
}

// ── 主流程 ──────────────────────────────────────────────────

const catalogArticles = await readCatalog();
const meta = await readArticleMeta();

// 依 slug 分組：一個 slug 是一個作品（Mvn 的一個 manifest 項目），
// 作品下可以有若干內容語言，每種語言下可以有若干文檔。
const works = [];
for (const article of catalogArticles) {
	let work = works.find((item) => item.slug === article.slug);
	if (!work) {
		work = { slug: article.slug, title: article.title, articles: [], languages: [], meta: meta[article.slug] ?? {} };
		works.push(work);
	}
	work.articles.push(article);
	if (!work.languages.includes(article.contentLang)) {
		work.languages.push(article.contentLang);
	}
}

// 排序：有日期就用日期，否則用標題，保證每次生成的順序一致。
works.sort((left, right) => {
	const leftDate = left.meta.date ?? "";
	const rightDate = right.meta.date ?? "";
	if (leftDate !== rightDate) {
		return rightDate.localeCompare(leftDate);
	}
	return left.title.localeCompare(right.title);
});
for (const work of works) {
	work.languages.sort((left, right) => localeOrder.indexOf(left) - localeOrder.indexOf(right));
}

const written = [];

async function emit(routePath, html) {
	const target = path.join(outDir, routePath.replace(/^\//, ""), "index.html");
	await mkdir(path.dirname(target), { recursive: true });
	await writeFile(target, html, "utf8");
	written.push(routePath);
}

function alternatesFor(logical) {
	// 站殼頁在每種站臺語言都有對應頁，故互為 hreflang 版本。
	if (logical.kind === "read") {
		// 正文頁的 hreflang 版本是同一篇的其他「內容語言」，不是介面語言；
		// 這些頁面的介面語言恰好等於各自的內容語言。
		const work = works.find((item) => item.slug === logical.slug);
		const items = (work?.articles ?? []).map((item) => ({ hreflang: item.contentLang, path: readingPath(item) }));
		const fallback = (work?.articles ?? []).find((item) => item.contentLang === defaultLocale);
		if (fallback) {
			items.push({ hreflang: "x-default", path: readingPath(fallback) });
		}
		return items;
	}
	return localeOrder.map((code) => ({ hreflang: code, path: logicalPath(logical, code) }));
}

let articleCount = 0;

for (const locale of localeOrder) {
	const strings = text(locale);

	// 首頁
	await emit(logicalPath({ kind: "home" }, locale), renderPage({
		locale,
		logical: { kind: "home", navKey: "home" },
		navKey: "home",
		title: strings.siteName,
		description: strings.tagline,
		hero: renderHero(locale, { title: strings.siteName, subtitle: strings.tagline }),
		main: `        <section class="section">
          <div class="section-head">
            <h2>${escapeHtml(strings.latestArticles)}</h2>
            <span class="count">${escapeHtml(strings.articleCount(works.length))}</span>
          </div>
          ${renderArticleList(locale, works)}
        </section>`,
		alternates: alternatesFor({ kind: "home" }),
	}));

	// 文章總覽
	await emit(listPath(locale), renderPage({
		locale,
		logical: { kind: "articles", navKey: "articles" },
		navKey: "articles",
		title: strings.allArticles,
		description: strings.listHint,
		hero: renderHero(locale, { compact: true, title: strings.allArticles, subtitle: strings.listHint }),
		main: `        ${renderArticleList(locale, works)}`,
		alternates: alternatesFor({ kind: "articles" }),
	}));

	// 單篇入口：列出這篇有哪些內容語言與格式
	for (const work of works) {
		const rows = work.articles.map((article) => {
			const docLabel = article.doc ? `<span class="lang-note">${escapeHtml(article.doc)}</span>` : "";
			const pdf = article.pdf ? `<a class="secondary-link" href="/articles/${work.slug}/${article.pdf}">${escapeHtml(strings.readPdf)}</a>` : "";
			const source = article.source ? `<a class="secondary-link" href="/articles/${work.slug}/${article.source}">${escapeHtml(strings.viewSource)}</a>` : "";
			return `<li>
              <span class="badge badge--lang">${escapeHtml(languageName(article.contentLang))}</span>
              <span class="lang-name">${escapeHtml(article.title)}</span>
              ${docLabel}
              <a class="button-link" href="${readingPath(article)}">${escapeHtml(strings.read)}</a>
              ${pdf}
              ${source}
            </li>`;
		}).join("\n");
		await emit(workPath(locale, work.slug), renderPage({
			locale,
			logical: { kind: "work", slug: work.slug, navKey: "articles" },
			navKey: "articles",
			title: preferredArticle(work, locale).title,
			description: work.meta.summary ?? strings.entryHint,
			hero: renderHero(locale, { compact: true, title: preferredArticle(work, locale).title, subtitle: work.meta.summary }),
			main: `        <section class="section">
          <div class="section-head">
            <h2>${escapeHtml(strings.entryTitle)}</h2>
            <span class="count">${escapeHtml(strings.entryHint)}</span>
          </div>
          <ul class="lang-list">
${rows}
          </ul>
        </section>`,
			alternates: alternatesFor({ kind: "work", slug: work.slug }),
		}));
	}

	// 施工中的站殼頁
	for (const key of stubPages) {
		await emit(stubPath(locale, key), renderPage({
			locale,
			logical: { kind: "stub", key, navKey: key },
			navKey: key,
			title: strings.nav[key],
			hero: renderHero(locale, { compact: true, title: strings.nav[key] }),
			main: `        <div class="card"><p class="hint">${escapeHtml(strings.underConstruction)}</p></div>`,
			alternates: alternatesFor({ kind: "stub", key }),
		}));
	}
}

// 正文頁：只生成「站臺語言＝內容語言」的組合。
for (const article of catalogArticles) {
	const locale = article.contentLang;
	const strings = text(locale);
	const bodyFile = path.join(articlesDir, article.slug, article.body);
	if (!existsSync(bodyFile)) {
		throw new Error(`build-site: 找不到正文片段 ${path.relative(root, bodyFile)}；請先跑 tools/ImportMvnPublish.csx`);
	}
	const body = await readFile(bodyFile, "utf8");
	const work = works.find((item) => item.slug === article.slug);
	const sameLanguage = (work?.articles ?? []).filter((item) => item.contentLang === locale);
	const index = sameLanguage.findIndex((item) => articleKey(item) === articleKey(article));
	const previous = index > 0 ? sameLanguage[index - 1] : null;
	const next = index >= 0 && index < sameLanguage.length - 1 ? sameLanguage[index + 1] : null;
	const pdf = article.pdf ? `<a class="button-link button-link--primary" href="/articles/${article.slug}/${article.pdf}">${escapeHtml(strings.readPdf)}</a>` : "";
	const source = article.source ? `<a class="button-link" href="/articles/${article.slug}/${article.source}">${escapeHtml(strings.viewSource)}</a>` : "";
	const foot = previous || next
		? `<nav class="reading-foot">
          <span>${previous ? `<a class="secondary-link" href="${readingPath(previous)}">&#8592; ${escapeHtml(strings.previous)}</a>` : ""}</span>
          <span>${next ? `<a class="secondary-link" href="${readingPath(next)}">${escapeHtml(strings.next)} &#8594;</a>` : ""}</span>
        </nav>`
		: "";

	await emit(readingPath(article), renderPage({
		locale,
		contentLang: locale,
		logical: { kind: "read", slug: article.slug, contentLang: locale, article, navKey: "articles" },
		navKey: "articles",
		title: article.title,
		description: work?.meta.summary ?? article.title,
		canonicalPath: readingPath(article),
		alternates: alternatesFor({ kind: "read", slug: article.slug, contentLang: locale }),
		publishedTime: work?.meta.date || undefined,
		tags: work?.meta.tags,
		toTop: true,
		main: `        <div class="reading-layout">
${renderToc(locale, article.toc)}
          <article class="reading">
            <header class="reading-head">
              <h1>${escapeHtml(article.title)}</h1>
              <div class="meta-row">
                <span class="badge badge--lang">${escapeHtml(strings.contentLanguage)}：${escapeHtml(languageName(locale))}</span>
                <span class="badge">${escapeHtml(strings.uiLanguage)}：${escapeHtml(languageName(locale))}</span>
                <a class="badge" href="${workPath(locale, article.slug)}">${escapeHtml(strings.entryTitle)}</a>
              </div>
              <div class="button-row">
                ${pdf}
                ${source}
              </div>
            </header>
            <div class="article-body">
${body}
            </div>
${foot}
          </article>
        </div>`,
	}));
	articleCount += 1;
}

// 404：GitHub Pages 會拿 dist/404.html 當找不到頁面時的內容。
await writeFile(path.join(outDir, "404.html"), renderPage({
	locale: defaultLocale,
	logical: { kind: "home", navKey: "home" },
	navKey: "home",
	title: "404",
	hero: renderHero(defaultLocale, { compact: true, title: "404" }),
	main: `        <div class="card"><p class="hint">找不到這個頁面。<a class="secondary-link" href="${homePath(defaultLocale)}">回到首頁</a></p></div>`,
}), "utf8");

// sitemap 與 robots：目前沒有後端，全部由靜態檔案提供。
// 直接掃 dist，故 Vite 建置的頁面（clean-disk）也在內，以後新增頁面種類不會漏。
// 404 不該進 sitemap；body.html 是正文片段，不是頁面。
async function collectRoutes(directory, prefix = "") {
	const entries = await readdir(directory, { withFileTypes: true });
	const routes = [];
	for (const entry of entries) {
		if (entry.isDirectory()) {
			routes.push(...await collectRoutes(path.join(directory, entry.name), `${prefix}/${entry.name}`));
			continue;
		}
		if (entry.name === "index.html") {
			routes.push(`${prefix}/`);
		}
		else if (entry.name.endsWith(".html") && entry.name !== "404.html" && entry.name !== "body.html") {
			routes.push(`${prefix}/${entry.name}`);
		}
	}
	return routes;
}

const pageRoutes = (await collectRoutes(outDir)).sort();
const sitemapUrls = pageRoutes.map((route) => `  <url><loc>${origin}${route}</loc></url>`).join("\n");
await writeFile(path.join(outDir, "sitemap.xml"), `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${sitemapUrls}
</urlset>
`, "utf8");
await writeFile(path.join(outDir, "robots.txt"), `User-agent: *
Allow: /

Sitemap: ${origin}/sitemap.xml
`, "utf8");

console.log(`build-site: 作品 ${works.length} 個、正文頁 ${articleCount} 個、頁面共 ${written.length} 個 → ${path.relative(root, outDir)}`);