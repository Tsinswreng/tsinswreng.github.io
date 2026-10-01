// 站點層級的唯一設定檔：站臺語言清單、界面文案、導航結構。
//
// 兩個容易混的詞，本檔與 tools/build-site.mjs 一律照這個定義用：
//   站臺語言（locale）：界面文字（導航、按鈕、頁腳、標籤）的語言。
//   內容語言（content language）：文章正文自己的語言，來自 Mvn manifest 的 Lang，
//     由 tools/ImportMvnPublish.csx 寫進 public/articles/catalog.json。
//
// 網址規則：
//   預設站臺語言不加前綴，其餘站臺語言一律加 /<站臺語言>/。
//   正文頁的網址一定帶內容語言那一段，不做省略，故不會產生同頁兩址。

export const origin = "https://tsinswreng.github.io";

export const defaultLocale = "zh-Hant";

// 順序即界面語言切換的顯示順序。
export const localeOrder = ["zh-Hant", "zh-Hans", "en", "ja", "es"];

// 站臺語言與內容語言的名稱都用該語言自己的寫法（endonym）：
// 讀者在語言切換器上要找的是自己認得的字，不是當前界面的譯名。
export const languageNames = {
	"zh-Hant": "繁體中文",
	"zh-Hans": "简体中文",
	en: "English",
	ja: "日本語",
	es: "Español",
};

// Open Graph 的語言寫法要求「語言_地區」，與本站網址前綴不同，故另立一表。
export const openGraphLocales = {
	"zh-Hant": "zh_TW",
	"zh-Hans": "zh_CN",
	en: "en_US",
	ja: "ja_JP",
	es: "es_ES",
};

// 全站導航。key 對應 ui[locale].nav[key] 的文案，path 是預設站臺語言下的路徑。
export const nav = [
	{ key: "home", path: "/" },
	{ key: "articles", path: "/articles/" },
	{ key: "projects", path: "/projects/" },
	{ key: "tools", path: "/tools/" },
	{ key: "about", path: "/about/" },
];

// 施工中的站殼頁。內容待補，先各生成一頁，免得導航指向不存在的網址。
export const stubPages = ["projects", "tools", "about"];

export const ui = {
	"zh-Hant": {
		siteName: "Tsinswreng",
		tagline: "文章、工具與專案",
		nav: { home: "首頁", articles: "文章", projects: "專案", tools: "工具", about: "關於" },
		latestArticles: "最新文章",
		allArticles: "全部文章",
		noArticles: "這個站臺語言還沒有可讀的文章。",
		listHint: "每篇的原文語言如下，正文一律以原文語言呈現。",
		read: "閱讀正文",
		readPdf: "閱讀 PDF",
		viewSource: "Typst 源碼",
		entryTitle: "版本與格式",
		entryHint: "這篇有哪幾種語言與格式。界面語言不會改變正文語言。",
		contentLanguage: "正文語言",
		uiLanguage: "界面語言",
		toc: "本篇目錄",
		copy: "複製",
		copied: "已複製",
		toTop: "回到頂部",
		sectionLink: "此節的連結",
		back: "後退",
		forward: "前進",
		previous: "上一篇",
		next: "下一篇",
		underConstruction: "這個頁面還在施工。",
		articleCount: (n) => `共 ${n} 篇文章`,
		onlyIn: (name) => `這篇文章目前只有${name}版。`,
		footerNote: "本站是各篇文章的權威版本，其他平臺的轉載以本站最新版為準。",
	},
	"zh-Hans": {
		siteName: "Tsinswreng",
		tagline: "文章、工具与项目",
		nav: { home: "首页", articles: "文章", projects: "项目", tools: "工具", about: "关于" },
		latestArticles: "最新文章",
		allArticles: "全部文章",
		noArticles: "这个站台语言还没有可读的文章。",
		listHint: "每篇的原文语言如下，正文一律以原文语言呈现。",
		read: "阅读正文",
		readPdf: "阅读 PDF",
		viewSource: "Typst 源码",
		entryTitle: "版本与格式",
		entryHint: "这篇有哪几种语言与格式。界面语言不会改变正文语言。",
		contentLanguage: "正文语言",
		uiLanguage: "界面语言",
		toc: "本篇目录",
		copy: "复制",
		copied: "已复制",
		toTop: "回到顶部",
		sectionLink: "此节的链接",
		back: "后退",
		forward: "前进",
		previous: "上一篇",
		next: "下一篇",
		underConstruction: "这个页面还在施工。",
		articleCount: (n) => `共 ${n} 篇文章`,
		onlyIn: (name) => `这篇文章目前只有${name}版。`,
		footerNote: "本站是各篇文章的权威版本，其他平台的转载以本站最新版为准。",
	},
	en: {
		siteName: "Tsinswreng",
		tagline: "Articles, tools and projects",
		nav: { home: "Home", articles: "Articles", projects: "Projects", tools: "Tools", about: "About" },
		latestArticles: "Latest",
		allArticles: "All articles",
		noArticles: "No readable articles in this interface language yet.",
		listHint: "Articles are always shown in the language they were written in.",
		read: "Read",
		readPdf: "Read PDF",
		viewSource: "Typst source",
		entryTitle: "Versions and formats",
		entryHint: "Which languages and formats this article has. The interface language never changes the article language.",
		contentLanguage: "Article language",
		uiLanguage: "Interface",
		toc: "Contents",
		copy: "Copy",
		copied: "Copied",
		toTop: "Back to top",
		sectionLink: "Link to this section",
		back: "Back",
		forward: "Forward",
		previous: "Previous",
		next: "Next",
		underConstruction: "This page is under construction.",
		articleCount: (n) => `${n} article${n === 1 ? "" : "s"}`,
		onlyIn: (name) => `This article is currently available in ${name} only.`,
		footerNote: "This site holds the authoritative version of every article. Copies elsewhere follow the latest version here.",
	},
	ja: {
		siteName: "Tsinswreng",
		tagline: "記事・ツール・プロジェクト",
		nav: { home: "ホーム", articles: "記事", projects: "プロジェクト", tools: "ツール", about: "このサイト" },
		latestArticles: "最新の記事",
		allArticles: "すべての記事",
		noArticles: "この表示言語で読める記事はまだありません。",
		listHint: "記事は書かれた言語のまま表示されます。",
		read: "本文を読む",
		readPdf: "PDF を読む",
		viewSource: "Typst ソース",
		entryTitle: "言語と形式",
		entryHint: "この記事が持つ言語と形式の一覧です。表示言語は本文の言語を変えません。",
		contentLanguage: "本文の言語",
		uiLanguage: "表示言語",
		toc: "目次",
		copy: "コピー",
		copied: "コピーしました",
		toTop: "先頭へ",
		sectionLink: "この節へのリンク",
		back: "戻る",
		forward: "進む",
		previous: "前の記事",
		next: "次の記事",
		underConstruction: "このページは準備中です。",
		articleCount: (n) => `全 ${n} 件`,
		onlyIn: (name) => `この記事は現在${name}版のみです。`,
		footerNote: "各記事の正式な版はこのサイトにあります。他サイトの転載はここの最新版に準じます。",
	},
	es: {
		siteName: "Tsinswreng",
		tagline: "Artículos, herramientas y proyectos",
		nav: { home: "Inicio", articles: "Artículos", projects: "Proyectos", tools: "Herramientas", about: "Acerca de" },
		latestArticles: "Recientes",
		allArticles: "Todos los artículos",
		noArticles: "Todavía no hay artículos legibles en este idioma de interfaz.",
		listHint: "Los artículos siempre se muestran en el idioma en que fueron escritos.",
		read: "Leer",
		readPdf: "Leer PDF",
		viewSource: "Código Typst",
		entryTitle: "Versiones y formatos",
		entryHint: "Idiomas y formatos disponibles. El idioma de la interfaz no cambia el idioma del artículo.",
		contentLanguage: "Idioma del artículo",
		uiLanguage: "Interfaz",
		toc: "Contenido",
		copy: "Copiar",
		copied: "Copiado",
		toTop: "Volver arriba",
		sectionLink: "Enlace a esta sección",
		back: "Atrás",
		forward: "Adelante",
		previous: "Anterior",
		next: "Siguiente",
		underConstruction: "Esta página está en construcción.",
		articleCount: (n) => `${n} artículo${n === 1 ? "" : "s"}`,
		onlyIn: (name) => `Este artículo solo está disponible en ${name} por ahora.`,
		footerNote: "Este sitio contiene la versión autorizada de cada artículo. Las copias en otros sitios siguen la última versión publicada aquí.",
	},
};

// 站臺語言在網址上的前綴。預設語言為空字串。
export function localePrefix(locale) {
	return locale === defaultLocale ? "" : `/${locale}`;
}

export function isLocale(value) {
	return localeOrder.includes(value);
}