// 將 Mvn 已構建的文檔匯入本站 public/articles；不編譯 Typst，也不推送 Git。
// dotnet script tools/ImportMvnPublish.csx <path-to-published-manifest.json>
#r "nuget: Tsinswreng.CsSh, 0.2.0-alpha"
#r "nuget: AngleSharp, 1.7.0"

#nullable enable

using AngleSharp;
using System.Net;
using System.Text.Json;
using System.Text.Json.Serialization;
using Tsinswreng.CsSh;
using static Tsinswreng.CsSh.ShGlobal;
using CT = System.Threading.CancellationToken;

var Config = new ImportConfig();
var Ct = CT.None;
var Json = new JsonSerializerOptions {
	PropertyNameCaseInsensitive = true,
};

if (Args.Count != 1) {
	await Write(Stderr, $"Usage: dotnet script {BaseName(CsxDir() / Config.ScriptFileName)} <path-to-published-manifest.json>{Environment.NewLine}", Ct);
	return 2;
}

try {
	await Import(Tsinswreng.CsSh.ShGlobal.Sh.FullPath(Args[0]), Ct);
}
catch (Exception Error) {
	await Write(Stderr, $"ImportMvnPublish: {Error.Message}{Environment.NewLine}", Ct);
	return 1;
}

async Task Import(Pth ManifestPath, CT Ct) {
	// 從腳本位置定位網站根目錄，避免呼叫者的工作目錄改變網站輸出位置。
	var SiteRoot = Tsinswreng.CsSh.ShGlobal.Sh.FullPath(CsxDir() / Config.ParentDirectoryName);
	var PublicRoot = SiteRoot / Config.PublicDirectoryName;
	var ArticlesRoot = PublicRoot / Config.ArticlesDirectoryName;
	if (!IsFile(ManifestPath) || !string.Equals(BaseName(ManifestPath), Config.ManifestFileName, StringComparison.OrdinalIgnoreCase)) {
		throw new Exception($"published manifest is required: {ManifestPath}");
	}

	var SourceRoot = DirName(ManifestPath);
	var Manifest = await ReadManifest(ManifestPath, Ct);
	var Slug = ReadSlug(Manifest);
	var Documents = ResolveDocuments(Manifest, SourceRoot);
	var Destination = RequireUnder(ArticlesRoot / Slug, ArticlesRoot);
	var Stage = RequireUnder(PublicRoot / $"{Config.StagingDirectoryPrefix}{Guid.NewGuid():N}", PublicRoot);

	try {
		await StageArticle(SourceRoot, Stage, Documents, Ct);
		await ReplaceArticle(Stage, Destination, ArticlesRoot, Ct);
		await UpdateArticleIndex(ArticlesRoot, Slug, Documents, Ct);
		await Echo($"imported {Manifest.Id} -> {Path.GetRelativePath(SiteRoot, Destination)}", Ct);
	}
	finally {
		// 成功移動後暫存路徑已不存在；Rm 的 rm -rf 語義會安全地忽略它。
		await Rm(Stage, Ct);
	}
}

async Task<PublishedManifest> ReadManifest(Pth ManifestPath, CT Ct) {
	// Content 保持檔案 I/O 的統一入口；manifest 很小，才在這裡完整讀為 JSON 文字。
	await using var Source = await Read(ManifestPath, Ct);
	var Text = await Source.Text(Ct);
	var Manifest = JsonSerializer.Deserialize<PublishedManifest>(Text, Json)
		?? throw new Exception($"cannot read manifest: {ManifestPath}");
	if (Manifest.Schema != Config.ManifestSchema) {
		throw new Exception($"unsupported manifest schema: {Manifest.Schema}");
	}
	return Manifest;
}

string ReadSlug(PublishedManifest Manifest) {
	// Slug 必須由文檔 manifest 顯式提供；匯入器絕不從項目名稱推導它。
	if (!Manifest.ExtensionData.TryGetValue(Config.SlugPropertyName, out var Value) || Value.ValueKind != JsonValueKind.String) {
		throw new Exception($"manifest {Config.SlugPropertyName} is required");
	}
	var Slug = Value.GetString() ?? "";
	if (!IsSlug(Slug)) {
		throw new Exception($"invalid slug '{Slug}'; expected lowercase kebab-case");
	}
	return Slug;
}

bool IsSlug(string Value) {
	// 連字號只能分隔非空詞，並拒絕大小寫、底線與 URL 路徑控制字元。
	if (Value.Length == 0 || Value[0] == Config.SlugSeparator || Value[^1] == Config.SlugSeparator) {
		return false;
	}
	var PreviousWasSeparator = false;
	foreach (var Character in Value) {
		if (Character == Config.SlugSeparator) {
			if (PreviousWasSeparator) {
				return false;
			}
			PreviousWasSeparator = true;
			continue;
		}
		if (!(Character is >= 'a' and <= 'z' || Character is >= '0' and <= '9')) {
			return false;
		}
		PreviousWasSeparator = false;
	}
	return true;
}

List<PublishedDocument> ResolveDocuments(PublishedManifest Manifest, Pth SourceRoot) {
	// 兩個 manifest 區段都產生同一組 HTML/PDF 發布入口，並以語言作為網站目錄名。
	var Result = new List<PublishedDocument>();
	var Languages = new HashSet<string>(StringComparer.Ordinal);
	AddDocuments(Manifest.SrcDocs, SourceRoot, Languages, Result);
	AddDocuments(Manifest.GeneratedDocs, SourceRoot, Languages, Result);
	if (Result.Count == 0) {
		throw new Exception("manifest has no documents");
	}
	return Result;
}

void AddDocuments(IReadOnlyDictionary<string, PublishedDoc> Entries, Pth SourceRoot, ISet<string> Languages, List<PublishedDocument> Result) {
	foreach (var Entry in Entries) {
		var FileName = Entry.Key;
		var Language = Entry.Value.Lang;
		if (!string.Equals(BaseName(FileName), FileName, StringComparison.Ordinal) || !FileName.EndsWith(Config.TypstExtension, StringComparison.OrdinalIgnoreCase)) {
			throw new Exception($"invalid document entry: {FileName}");
		}
		if (!IsPathSegment(Language) || !Languages.Add(Language)) {
			throw new Exception($"document language must be a unique path segment: {Language}");
		}
		var Name = Path.GetFileNameWithoutExtension(FileName);
		var TypSource = RequireUnder(SourceRoot / FileName, SourceRoot);
		var HtmlSource = RequireUnder(SourceRoot / $"{Name}{Config.HtmlExtension}", SourceRoot);
		var PdfSource = RequireUnder(SourceRoot / $"{Name}{Config.PdfExtension}", SourceRoot);
		if (!IsFile(TypSource) || !IsFile(HtmlSource) || !IsFile(PdfSource)) {
			throw new Exception($"published Typst, HTML, and PDF are required for {FileName}");
		}
		Result.Add(new(Language, TypSource, HtmlSource, PdfSource));
	}
}

bool IsPathSegment(string Value) {
	// 語言標籤只需安全地成為一級目錄名；不在匯入器內重新實作 BCP 47 驗證。
	return !string.IsNullOrWhiteSpace(Value)
		&& Value != Config.CurrentDirectoryName
		&& Value != Config.ParentDirectoryName
		&& !Value.Contains(Path.DirectorySeparatorChar)
		&& !Value.Contains(Path.AltDirectorySeparatorChar);
}

async Task StageArticle(Pth SourceRoot, Pth Stage, List<PublishedDocument> Documents, CT Ct) {
	// 暫存目錄完整就緒後才替換公開文章，避免構建失敗破壞既有版本。
	var SourceAssets = SourceRoot / Config.AssetsDirectoryName;
	var StageAssets = Stage / Config.AssetsDirectoryName;
	await Mkdir(Stage, Ct);
	if (IsDir(SourceAssets)) {
		await Mkdir(StageAssets, Ct);
		await Cp(SourceAssets / Config.AllFilesGlob, StageAssets, new(Overwrite: true), Ct);
	}

	var OutputPaths = CreateOutputPaths(Documents, Stage);
	var StageSources = Stage / Config.SourceDirectoryName;
	await CopySourceBundle(SourceRoot, SourceAssets, StageSources, Ct);
	foreach (var Document in Documents) {
		var HtmlDestination = OutputPaths[Document.HtmlSource.Value];
		var PdfDestination = OutputPaths[Document.PdfSource.Value];
		var TypDestination = StageSources / BaseName(Document.TypSource);
		await Mkdir(DirName(HtmlDestination), Ct);
		await RewriteHtml(Document.HtmlSource, HtmlDestination, TypDestination, SourceRoot, SourceAssets, StageAssets, OutputPaths, Ct);
		await Cp(Document.PdfSource, PdfDestination, new(Overwrite: true), Ct);
	}
}

async Task CopySourceBundle(Pth SourceRoot, Pth SourceAssets, Pth StageSources, CT Ct) {
	// 原始碼與其本地 assets 維持發布目錄的相對關係，讓讀者取得的內容仍可供 Typst 使用。
	await Mkdir(StageSources, Ct);
	foreach (var SourceFile in Ls(SourceRoot).OfType<FileInfo>()) {
		if (string.Equals(SourceFile.Extension, Config.TypstExtension, StringComparison.OrdinalIgnoreCase)) {
			await Cp(SourceFile.FullName, StageSources / SourceFile.Name, new(Overwrite: true), Ct);
		}
	}
	if (IsDir(SourceAssets)) {
		var StageSourceAssets = StageSources / Config.AssetsDirectoryName;
		await Mkdir(StageSourceAssets, Ct);
		await Cp(SourceAssets / Config.AllFilesGlob, StageSourceAssets, new(Overwrite: true), Ct);
	}
}

Dictionary<string, Pth> CreateOutputPaths(List<PublishedDocument> Documents, Pth Stage) {
	// 先建立完整映射，使文章中的同項目 HTML/PDF 相對鏈接也能隨目錄重排而保持有效。
	var Result = new Dictionary<string, Pth>(StringComparer.OrdinalIgnoreCase);
	foreach (var Document in Documents) {
		var LanguageRoot = Stage / Document.Lang;
		Result.Add(Document.HtmlSource.Value, LanguageRoot / Config.HtmlIndexFileName);
		Result.Add(Document.PdfSource.Value, LanguageRoot / Config.PdfArticleFileName);
	}
	return Result;
}

async Task RewriteHtml(Pth HtmlSource, Pth HtmlDestination, Pth TypDestination, Pth SourceRoot, Pth SourceAssets, Pth StageAssets, IReadOnlyDictionary<string, Pth> OutputPaths, CT Ct) {
	// AngleSharp 只處理已構建 HTML 的資源 URL；不解析 Typst 正文，也不猜測資產列表。
	await using var Source = await Read(HtmlSource, Ct);
	var Html = await Source.Text(Ct);
	var Context = BrowsingContext.New(Configuration.Default);
	var Document = await Context.OpenAsync(Requester => Requester.Content(Html), Ct);
	foreach (var Element in Document.QuerySelectorAll(Config.HtmlResourceSelector)) {
		foreach (var AttributeName in Config.HtmlUrlAttributeNames) {
			var Value = Element.GetAttribute(AttributeName);
			if (Value is null || !TryResolveRelativeUrl(Value, SourceRoot, out var SourcePath, out var Suffix)) {
				continue;
			}
			var DestinationPath = MapPublishedPath(SourcePath, SourceAssets, StageAssets, OutputPaths);
			if (DestinationPath is null) {
				continue;
			}
			var Relative = Path.GetRelativePath(DirName(HtmlDestination), DestinationPath.Value)
				.Replace(Path.DirectorySeparatorChar, Config.UrlPathSeparator);
			Element.SetAttribute(AttributeName, Relative + Suffix);
		}
	}

	// Mvn 的 _Common.typ 會為整個 HTML 文件設定黑底與大字；本站需要自己負責頁面外殼和排版。
	foreach (var Style in Document.QuerySelectorAll("style[data-mvn-style]")) {
		Style.Remove();
	}
	var Article = Document.Body?.QuerySelector("article");
	var Heading = Article?.QuerySelector("h1");
	var Title = Heading?.TextContent.Trim();
	if (string.IsNullOrWhiteSpace(Title)) {
		Title = Config.DefaultArticleTitle;
	}
	// 文章的唯一一級標題放在本站 hero 中，避免同頁出現兩個相同標題。
	Heading?.Remove();
	var ArticleHtml = Article?.OuterHtml ?? Document.Body?.InnerHtml ?? "";
	var SourceUrl = Path.GetRelativePath(DirName(HtmlDestination), TypDestination).Replace(Path.DirectorySeparatorChar, Config.UrlPathSeparator);
	// 每個語言頁固定位於 <slug>/<lang>/index.html，樣式表位於 articles 根目錄。
	var ArticleCssUrl = $"{Config.ParentDirectoryName}/{Config.ParentDirectoryName}/{Config.ArticleStylesheetFileName}";
	var Language = WebUtility.HtmlEncode(Path.GetFileName(DirName(HtmlDestination).Value));
	await Write(HtmlDestination, BuildArticlePage(Title, Language, ArticleHtml, SourceUrl, ArticleCssUrl), Ct);
}

string BuildArticlePage(string Title, string Language, string ArticleHtml, string SourceUrl, string ArticleCssUrl) {
	var EncodedTitle = WebUtility.HtmlEncode(Title);
	return $$"""
<!doctype html>
<html lang="{{Language}}">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="{{EncodedTitle}}">
    <title>{{EncodedTitle}}｜Tsinswreng</title>
    <link rel="stylesheet" href="{{ArticleCssUrl}}">
  </head>
  <body>
    <nav class="site-nav" aria-label="全站導航">
      <div class="site-nav-inner">
        <a class="brand" href="/">Tsinswreng</a>
        <div class="nav-links">
          <a href="/">首頁</a>
          <a href="/#articles">文章</a>
          <a href="/#projects">專案</a>
          <a href="/#tools">工具</a>
          <a href="/#about">關於</a>
        </div>
      </div>
    </nav>
    <header class="site-hero">
      <div class="site-hero-inner">
        <h1>{{EncodedTitle}}</h1>
      </div>
    </header>
    <main class="site-main">
      <article class="article-shell">
        <header class="article-actions">
          <a class="button-link" href="article.pdf">閱讀 PDF</a>
          <a class="secondary-link" href="{{SourceUrl}}">{{Config.TypstSourceLinkText}}</a>
        </header>
        <div class="article-body">
{{ArticleHtml}}
        </div>
      </article>
    </main>
    <footer class="site-footer"><p>© {{DateTime.Now.Year}} Tsinswreng</p></footer>
  </body>
</html>
""";
}

bool TryResolveRelativeUrl(string Value, Pth SourceRoot, out Pth SourcePath, out string Suffix) {
	SourcePath = default;
	Suffix = "";
	if (string.IsNullOrWhiteSpace(Value)
		|| Value.StartsWith(Config.FragmentPrefix, StringComparison.Ordinal)
		|| Value.StartsWith(Config.RootPathPrefix, StringComparison.Ordinal)
		|| Value.StartsWith(Config.ProtocolRelativePrefix, StringComparison.Ordinal)
		|| Uri.IsWellFormedUriString(Value, UriKind.Absolute)) {
		return false;
	}
	var Cut = Value.IndexOfAny(Config.UrlSuffixSeparators);
	var Relative = Cut < 0 ? Value : Value[..Cut];
	Suffix = Cut < 0 ? "" : Value[Cut..];
	if (Relative.Length == 0) {
		return false;
	}
	SourcePath = RequireUnder(SourceRoot / Uri.UnescapeDataString(Relative), SourceRoot);
	return true;
}

Pth? MapPublishedPath(Pth SourcePath, Pth SourceAssets, Pth StageAssets, IReadOnlyDictionary<string, Pth> OutputPaths) {
	// 可發布文件和 assets 都有明確目標；其他相對鏈接保留原樣，交由文檔作者決定其語義。
	if (OutputPaths.TryGetValue(SourcePath.Value, out var DocumentOutput)) {
		return DocumentOutput;
	}
	if (!IsUnder(SourcePath, SourceAssets)) {
		return null;
	}
	if (!IsFile(SourcePath)) {
		throw new Exception($"linked asset does not exist: {SourcePath}");
	}
	return StageAssets / Path.GetRelativePath(SourceAssets, SourcePath);
}

async Task UpdateArticleIndex(Pth ArticlesRoot, string Slug, List<PublishedDocument> Documents, CT Ct) {
	var IndexPath = ArticlesRoot / Config.ArticleIndexFileName;
	var Entries = new List<ArticleIndexEntry>();
	if (IsFile(IndexPath)) {
		await using var Existing = await Read(IndexPath, Ct);
		Entries = JsonSerializer.Deserialize<List<ArticleIndexEntry>>(await Existing.Text(Ct), Json) ?? new();
	}
	Entries.RemoveAll(Entry => string.Equals(Entry.Slug, Slug, StringComparison.OrdinalIgnoreCase));
	foreach (var Document in Documents) {
		await using var Source = await Read(Document.HtmlSource, Ct);
		var Html = await Source.Text(Ct);
		var Parsed = await BrowsingContext.New(Configuration.Default).OpenAsync(Requester => Requester.Content(Html), Ct);
		var Title = Parsed.Body?.QuerySelector("article h1")?.TextContent.Trim() ?? Slug;
		Entries.Add(new ArticleIndexEntry(Slug, Document.Lang, Title, "/articles/" + Slug + "/" + Document.Lang + "/"));
	}
	Entries.Sort((Left, Right) => string.Compare(Left.Slug + "/" + Left.Lang, Right.Slug + "/" + Right.Lang, StringComparison.Ordinal));
	await Mkdir(ArticlesRoot, Ct);
	await Write(IndexPath, JsonSerializer.Serialize(Entries, new JsonSerializerOptions(Json) {
		PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
		WriteIndented = true,
	}) + Environment.NewLine, Ct);
}

async Task ReplaceArticle(Pth Stage, Pth Destination, Pth ArticlesRoot, CT Ct) {
	// 替換範圍固定為單一 slug，防止匯入器影響同站其他文章。
	await Mkdir(ArticlesRoot, Ct);
	await Rm(Destination, Ct);
	await Mv(Stage, Destination, Ct);
}

Pth RequireUnder(Pth Candidate, Pth Parent) {
	// Cssh 的 FullPath 統一絕對路徑；額外相對路徑檢查保護刪除與複製目標不越出受管目錄。
	var FullCandidate = Tsinswreng.CsSh.ShGlobal.Sh.FullPath(Candidate);
	var FullParent = Tsinswreng.CsSh.ShGlobal.Sh.FullPath(Parent);
	if (!IsUnder(FullCandidate, FullParent)) {
		throw new Exception($"path escapes its expected root: {Candidate}");
	}
	return FullCandidate;
}

bool IsUnder(Pth Candidate, Pth Parent) {
	var Relative = Path.GetRelativePath(
		Tsinswreng.CsSh.ShGlobal.Sh.FullPath(Parent).Value,
		Tsinswreng.CsSh.ShGlobal.Sh.FullPath(Candidate).Value);
	return Relative != Config.ParentDirectoryName
		&& !Relative.StartsWith(Config.ParentDirectoryName + Path.DirectorySeparatorChar, StringComparison.Ordinal)
		&& !Path.IsPathRooted(Relative);
}

sealed class ImportConfig {
	public string ScriptFileName { get; } = "ImportMvnPublish.csx";
	public string ParentDirectoryName { get; } = "..";
	public string PublicDirectoryName { get; } = "public";
	public string ArticlesDirectoryName { get; } = "articles";
	public string SourceDirectoryName { get; } = "source";
	public string AssetsDirectoryName { get; } = "assets";
	public string StagingDirectoryPrefix { get; } = ".mvn-import-";
	public string AllFilesGlob { get; } = "*";
	public string ManifestFileName { get; } = "manifest.json";
	public string ManifestSchema { get; } = "1";
	public string SlugPropertyName { get; } = "Slug";
	public char SlugSeparator { get; } = '-';
	public string TypstExtension { get; } = ".typ";
	public string HtmlExtension { get; } = ".html";
	public string PdfExtension { get; } = ".pdf";
	public string HtmlIndexFileName { get; } = "index.html";
	public string PdfArticleFileName { get; } = "article.pdf";
	public string ArticleIndexFileName { get; } = "index.json";
	public string ArticleStylesheetFileName { get; } = "article-page.css";
	public string DefaultArticleTitle { get; } = "文章";
	public string TypstSourceLinkText { get; } = "Typst 源碼";
	public string HtmlResourceSelector { get; } = "[src], [href]";
	public string[] HtmlUrlAttributeNames { get; } = ["src", "href"];
	public char[] UrlSuffixSeparators { get; } = ['?', '#'];
	public string FragmentPrefix { get; } = "#";
	public string RootPathPrefix { get; } = "/";
	public string ProtocolRelativePrefix { get; } = "//";
	public char UrlPathSeparator { get; } = '/';
	public string CurrentDirectoryName { get; } = ".";
}

record PublishedManifest {
	public string Schema { get; init; } = "";
	public string Id { get; init; } = "";
	public Dictionary<string, PublishedDoc> SrcDocs { get; init; } = new();
	public Dictionary<string, PublishedDoc> GeneratedDocs { get; init; } = new();
	[JsonExtensionData]
	public Dictionary<string, JsonElement> ExtensionData { get; init; } = new();
}

record PublishedDoc {
	public string Lang { get; init; } = "";
}

record PublishedDocument(string Lang, Pth TypSource, Pth HtmlSource, Pth PdfSource);
record ArticleIndexEntry(string Slug, string Lang, string Title, string Url);
