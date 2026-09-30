// 將 Mvn 已構建的文檔匯入本站 public/articles；不編譯 Typst，也不推送 Git。
// dotnet script tools/ImportMvnPublish.csx <path-to-published-manifest.json>
// 支援兩種發布佈局：schema 1 逐檔列入口、產物在項目發布目錄根；
// schema 2 以目錄為單位、產物在 <語言目錄>/ 下。
#r "nuget: Tsinswreng.CsSh, 0.2.0-alpha"
#r "nuget: AngleSharp, 1.7.0"

#nullable enable

using AngleSharp;
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
		var Pages = await StageArticle(SourceRoot, Stage, Documents, Manifest.Schema, Slug, Ct);
		await ReplaceArticle(Stage, Destination, ArticlesRoot, Ct);
		await UpdateArticleCatalog(ArticlesRoot, Slug, Manifest.Id, Pages, Ct);
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
	if (Manifest.Schema != Config.ManifestSchema && Manifest.Schema != Config.ManifestSchemaV2) {
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
	// 兩種 schema 都歸一到同一份頁面清單：每個元素是一個要發布的網頁。
	var Result = Manifest.Schema == Config.ManifestSchemaV2
		? ResolveV2Documents(Manifest, SourceRoot)
		: ResolveV1Documents(Manifest, SourceRoot);
	if (Result.Count == 0) {
		throw new Exception("manifest has no documents");
	}
	return Result;
}

List<PublishedDocument> ResolveV1Documents(PublishedManifest Manifest, Pth SourceRoot) {
	// V1 逐個文件列入口；入口與三份產物都躺在項目發布目錄根。
	var Result = new List<PublishedDocument>();
	var Languages = new HashSet<string>(StringComparer.Ordinal);
	foreach (var Section in new[] { Manifest.SrcDocs, Manifest.GeneratedDocs }) {
		if (Section is null) {
			continue;
		}
		foreach (var Entry in Section) {
			var FileName = Entry.Key;
			var Language = Entry.Value.Lang;
			if (!string.Equals(BaseName(FileName), FileName, StringComparison.Ordinal) || !FileName.EndsWith(Config.TypstExtension, StringComparison.OrdinalIgnoreCase)) {
				throw new Exception($"invalid document entry: {FileName}");
			}
			if (!IsPathSegment(Language) || !Languages.Add(Language)) {
				throw new Exception($"document language must be a unique path segment: {Language}");
			}
			var Name = Path.GetFileNameWithoutExtension(FileName);
			// V1 一種語言只有一個文檔，故沒有文檔名那一段，正文片段固定叫 body.html。
			Result.Add(new PublishedDocument(
				Language,
				RequireFile(SourceRoot / FileName, SourceRoot),
				RequireFile(SourceRoot / $"{Name}{Config.HtmlExtension}", SourceRoot),
				RequireFile(SourceRoot / $"{Name}{Config.PdfExtension}", SourceRoot),
				$"{Language}/{Config.PdfArticleFileName}",
				$"{Name}{Config.TypstExtension}",
				Config.EmptyDocId,
				$"{Language}/{Config.BodyFileName}"));
		}
	}
	return Result;
}

List<PublishedDocument> ResolveV2Documents(PublishedManifest Manifest, Pth SourceRoot) {
	// V2 以目錄為單位：一條目錄一棵樹，語言寫在目錄上，產物跟源碼同深度地落在 <語言目錄>/ 下。
	var Result = new List<PublishedDocument>();
	var Languages = new HashSet<string>(StringComparer.Ordinal);
	var Resolved = new Dictionary<string, PublishedDir>(StringComparer.Ordinal);
	foreach (var Dir in EnumerateDirectories(Manifest)) {
		var Language = Dir.Lang;
		if (!IsPathSegment(Language) || !Languages.Add(Language)) {
			throw new Exception($"document language must be a unique path segment: {Language}");
		}
		var Directory = NormalizeDirectory(Dir.Path);
		if (Resolved.ContainsKey(Directory)) {
			throw new Exception($"duplicate directory: {Dir.Path}");
		}
		// 生成目錄不重列 Docs：它的入口清單與 EntryPoint 都跟來源目錄一致，只有語言和位置不同。
		var Docs = Dir.Docs ?? new List<PublishedDocEntry>();
		var EntryPoint = Dir.EntryPoint;
		if (Docs.Count == 0) {
			var From = NormalizeDirectory(Dir.GeneratorOptions?.From ?? "");
			if (Dir.GeneratorOptions is null || !Resolved.TryGetValue(From, out var Source)) {
				throw new Exception($"directory has no document entry and no resolved source directory: {Dir.Path}");
			}
			Docs = Source.Docs ?? new List<PublishedDocEntry>();
			EntryPoint ??= Source.EntryPoint;
		}
		// foreach 迭代變數不可指派，故把解析結果放進 Current，後面一律用它。
		var Current = Dir with { Path = Directory, Docs = Docs, EntryPoint = EntryPoint };
		Resolved.Add(Directory, Current);
		// 首頁必須明確：只有一篇時就是它，多篇時由 EntryPoint 指定。
		var EntryFile = NormalizeDocumentPath(Current.EntryPoint);
		var Entry = EntryFile.Length == 0
			? null
			: Docs.FirstOrDefault(Doc => string.Equals(NormalizeDocumentPath(Doc.File), EntryFile, StringComparison.Ordinal));
		if (Entry is null) {
			if (Docs.Count > 1) {
				throw new Exception($"language {Language} has {Docs.Count} documents; declare EntryPoint to pick the index page");
			}
			Entry = Docs[0];
		}
		var EntryPath = NormalizeDocumentPath(Entry.File);
		foreach (var Doc in Docs) {
			var File = NormalizeDocumentPath(Doc.File);
			if (!File.EndsWith(Config.TypstExtension, StringComparison.OrdinalIgnoreCase)) {
				throw new Exception($"invalid document entry: {Doc.File}");
			}
			var Stem = Path.GetFileNameWithoutExtension(File);
			var Published = JoinRelative(Directory, File);
			var IsEntry = string.Equals(File, EntryPath, StringComparison.Ordinal);
			// 網站側的正文網址是一段目錄：一種語言只有一個文檔時就落在語言目錄本身，
			// 多個文檔時各加一層以檔名為名的目錄。故正文片段的檔名也跟著分兩種。
			Result.Add(new PublishedDocument(
				Language,
				RequireFile(SourceRoot / Published, SourceRoot),
				RequireFile(SourceRoot / JoinRelative(Directory, $"{Stem}{Config.HtmlExtension}"), SourceRoot),
				RequireFile(SourceRoot / JoinRelative(Directory, $"{Stem}{Config.PdfExtension}"), SourceRoot),
				IsEntry ? $"{Language}/{Config.PdfArticleFileName}" : $"{Language}/{Stem}{Config.PdfExtension}",
				Published,
				IsEntry ? Config.EmptyDocId : Stem,
				IsEntry ? $"{Language}/{Config.BodyFileName}" : $"{Language}/{Stem}.{Config.BodyFileName}"));
		}
	}
	return Result;
}

IEnumerable<PublishedDir> EnumerateDirectories(PublishedManifest Manifest) {
	// 源目錄先於生成目錄；兩者都是同一種「一棵樹」的宣告。
	foreach (var Dir in Manifest.SrcDirs ?? new List<PublishedDir>()) {
		yield return Dir;
	}
	foreach (var Dir in Manifest.GeneratedDirs ?? new List<PublishedDir>()) {
		yield return Dir;
	}
}

string NormalizeDirectory(string Value) {
	// 目錄路徑進得了 URL 與暫存目錄；只接受相對路徑，空字串與 "." 表示項目根。
	var Normalized = (Value ?? "").Replace('\\', '/').Trim('/');
	if (Normalized is "." or "") {
		return "";
	}
	if (Path.IsPathRooted(Normalized) || Normalized.Contains("..", StringComparison.Ordinal)) {
		throw new Exception($"invalid relative directory path: {Value}");
	}
	return Normalized;
}

string NormalizeDocumentPath(string? Value) {
	var Normalized = (Value ?? "").Replace('\\', '/').Trim('/');
	if (Normalized.Length == 0) {
		return "";
	}
	if (Path.IsPathRooted(Normalized) || Normalized.Contains("..", StringComparison.Ordinal)) {
		throw new Exception($"invalid relative document path: {Value}");
	}
	return Normalized;
}

string JoinRelative(string Directory, string File) {
	return Directory.Length == 0 ? File : $"{Directory}/{File}";
}

Pth RequireFile(Pth Candidate, Pth Parent) {
	var Full = RequireUnder(Candidate, Parent);
	if (!IsFile(Full)) {
		throw new Exception($"published Typst, HTML, and PDF are required: {Candidate}");
	}
	return Full;
}

bool IsPathSegment(string Value) {
	// 語言標籤只需安全地成為一級目錄名；不在匯入器內重新實作 BCP 47 驗證。
	return !string.IsNullOrWhiteSpace(Value)
		&& Value != Config.CurrentDirectoryName
		&& Value != Config.ParentDirectoryName
		&& !Value.Contains(Path.DirectorySeparatorChar)
		&& !Value.Contains(Path.AltDirectorySeparatorChar);
}

async Task<List<ArticlePage>> StageArticle(Pth SourceRoot, Pth Stage, List<PublishedDocument> Documents, string Schema, string Slug, CT Ct) {
	// 暫存目錄完整就緒後才替換公開文章，避免構建失敗破壞既有版本。
	// 兩種佈局的 assets 都在項目發布目錄根，故共用同一段複製。
	var SourceAssets = SourceRoot / Config.AssetsDirectoryName;
	var StageAssets = Stage / Config.AssetsDirectoryName;
	await Mkdir(Stage, Ct);
	if (IsDir(SourceAssets)) {
		await Mkdir(StageAssets, Ct);
		await Cp(SourceAssets / Config.AllFilesGlob, StageAssets, new(Overwrite: true), Ct);
	}

	// 同一專案內文件互鏈改用站根相對網址，故發布副本搬到哪一層都不會斷。
	var DocumentUrls = CreateDocumentUrls(Documents, Slug);
	var Pages = new List<ArticlePage>();
	var StageSources = Stage / Config.SourceDirectoryName;
	await CopySourceBundle(SourceRoot, SourceAssets, StageSources, Schema, Ct);
	foreach (var Entry in Documents) {
		var BodyDestination = Stage / Entry.BodyRelative;
		var PdfDestination = Stage / Entry.PdfRelative;
		var TypDestination = StageSources / Entry.SourceRelative;
		await Mkdir(DirName(BodyDestination), Ct);
		Pages.Add(await RewriteHtml(Entry, BodyDestination, TypDestination, Slug, SourceRoot, SourceAssets, DocumentUrls, Ct));
		await Cp(Entry.PdfSource, PdfDestination, new(Overwrite: true), Ct);
	}
	return Pages;
}

async Task CopySourceBundle(Pth SourceRoot, Pth SourceAssets, Pth StageSources, string Schema, CT Ct) {
	// 原始碼與其本地 assets 維持發布目錄的相對關係，讓讀者取得的內容仍可供 Typst 使用。
	await Mkdir(StageSources, Ct);
	foreach (var SourceFile in EnumerateSourceFiles(SourceRoot, Schema)) {
		var Destination = StageSources / Path.GetRelativePath(SourceRoot.Value, SourceFile.Value);
		await Mkdir(DirName(Destination), Ct);
		await Cp(SourceFile, Destination, new(Overwrite: true), Ct);
	}
	if (IsDir(SourceAssets)) {
		var StageSourceAssets = StageSources / Config.AssetsDirectoryName;
		await Mkdir(StageSourceAssets, Ct);
		await Cp(SourceAssets / Config.AllFilesGlob, StageSourceAssets, new(Overwrite: true), Ct);
	}
}

IEnumerable<Pth> EnumerateSourceFiles(Pth SourceRoot, string Schema) {
	// V1 的入口都在發布目錄根，故只取頂層；V2 的入口在語言目錄裏，故要遞迴。
	if (Schema != Config.ManifestSchemaV2) {
		foreach (var SourceFile in Ls(SourceRoot).OfType<FileInfo>()) {
			if (string.Equals(SourceFile.Extension, Config.TypstExtension, StringComparison.OrdinalIgnoreCase)) {
				yield return Tsinswreng.CsSh.ShGlobal.Sh.FullPath(SourceFile.FullName);
			}
		}
		yield break;
	}
	foreach (var SourceFile in Directory.EnumerateFiles(SourceRoot.Value, "*" + Config.TypstExtension, SearchOption.AllDirectories)) {
		yield return Tsinswreng.CsSh.ShGlobal.Sh.FullPath(SourceFile);
	}
}

Dictionary<string, string> CreateDocumentUrls(List<PublishedDocument> Documents, string Slug) {
	// 正文片段裡的同專案互鏈一律寫成本站正式網址，故片段被放到哪個路徑下都仍然有效。
	var Result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
	foreach (var Entry in Documents) {
		Result[Entry.HtmlSource.Value] = Entry.DocId.Length == 0
			? $"{Config.ArticlesUrlPrefix}/{Slug}/{Entry.Lang}/"
			: $"{Config.ArticlesUrlPrefix}/{Slug}/{Entry.Lang}/{Entry.DocId}/";
	}
	return Result;
}

async Task<ArticlePage> RewriteHtml(PublishedDocument Entry, Pth BodyDestination, Pth TypDestination, string Slug, Pth SourceRoot, Pth SourceAssets, IReadOnlyDictionary<string, string> DocumentUrls, CT Ct) {
	// AngleSharp 只處理已構建 HTML 的資源 URL；不解析 Typst 正文，也不猜測資產列表。
	// 輸出的是正文片段（<article class="mvn-article">…</article>），整頁外殼由 tools/build-site.mjs 負責。
	await using var Source = await Read(Entry.HtmlSource, Ct);
	var Html = await Source.Text(Ct);
	var Context = BrowsingContext.New(Configuration.Default);
	var Page = await Context.OpenAsync(Requester => Requester.Content(Html), Ct);
	var SiteBase = $"{Config.ArticlesUrlPrefix}/{Slug}";
	foreach (var Element in Page.QuerySelectorAll(Config.HtmlResourceSelector)) {
		foreach (var AttributeName in Config.HtmlUrlAttributeNames) {
			var Value = Element.GetAttribute(AttributeName);
			// 相對網址以該 HTML 自己所在的目錄為基準；V2 的 HTML 在語言目錄下，故基準不是發布目錄根。
			if (Value is null || !TryResolveRelativeUrl(Value, SourceRoot, DirName(Entry.HtmlSource), out var SourcePath, out var Suffix)) {
				continue;
			}
			var Url = MapPublishedUrl(SourcePath, SiteBase, SourceAssets, DocumentUrls);
			if (Url is null) {
				continue;
			}
			Element.SetAttribute(AttributeName, Url + Suffix);
		}
	}

	// Mvn 的 _Common.typ 會為整個 HTML 文件設定黑底與大字；本站需要自己負責頁面外殼和排版。
	foreach (var Style in Page.QuerySelectorAll("style[data-mvn-style]")) {
		Style.Remove();
	}
	var Article = Page.Body?.QuerySelector("article");
	var Heading = Article?.QuerySelector("h1");
	var Title = Heading?.TextContent.Trim();
	if (string.IsNullOrWhiteSpace(Title)) {
		Title = Config.DefaultArticleTitle;
	}
	// 文章的唯一一級標題交給本站頁首，避免同頁出現兩個相同標題。
	Heading?.Remove();
	// Mvn 匯出的標題不帶 id，故在這裏補；同時記下目錄，網站側不必再解析 HTML。
	var Toc = new List<TocEntry>();
	if (Article is not null) {
		var UsedIds = new HashSet<string>(StringComparer.Ordinal);
		foreach (var Item in Article.QuerySelectorAll(Config.TocHeadingSelector)) {
			if (Item.LocalName.Length != 2 || !int.TryParse(Item.LocalName[1..], out var Level)) {
				continue;
			}
			var Name = Item.TextContent.Trim();
			var Id = Item.GetAttribute("id");
			if (string.IsNullOrWhiteSpace(Id) || UsedIds.Contains(Id)) {
				Id = UniqueAnchor(Name, UsedIds);
				Item.SetAttribute("id", Id);
			}
			UsedIds.Add(Id);
			// 標題末尾的「#」是可直接分享的錨點連結；純裝飾，故不進目錄文字。
			var Anchor = Page.CreateElement("a");
			Anchor.ClassName = Config.HeadingAnchorClassName;
			Anchor.SetAttribute("href", $"#{Id}");
			Anchor.TextContent = Config.HeadingAnchorText;
			Item.AppendChild(Anchor);
			Toc.Add(new TocEntry(Id, Name, Level));
		}
	}
	var ArticleHtml = Article?.OuterHtml ?? Page.Body?.InnerHtml ?? "";
	await Write(BodyDestination, ArticleHtml, Ct);
	return new ArticlePage(
		Entry.Lang,
		Entry.DocId,
		Title,
		Entry.BodyRelative,
		Entry.PdfRelative,
		$"{Config.SourceDirectoryName}/{Entry.SourceRelative}",
		Toc);
}

string UniqueAnchor(string Name, HashSet<string> UsedIds) {
	// 標題文字的空白與標點換成連字號；中日韓字是字母，故中文標題會直接留下來當錨點。
	var Characters = new List<char>();
	foreach (var Character in Name) {
		if (char.IsLetterOrDigit(Character)) {
			Characters.Add(Character);
		}
		else if (Characters.Count > 0 && Characters[^1] != '-') {
			Characters.Add('-');
		}
	}
	while (Characters.Count > 0 && Characters[^1] == '-') {
		Characters.RemoveAt(Characters.Count - 1);
	}
	var Base = Characters.Count == 0 ? Config.DefaultAnchorName : new string(Characters.ToArray());
	var Candidate = Base;
	var Index = 2;
	while (UsedIds.Contains(Candidate)) {
		Candidate = $"{Base}-{Index++}";
	}
	return Candidate;
}

bool TryResolveRelativeUrl(string Value, Pth SourceRoot, Pth HtmlDirectory, out Pth SourcePath, out string Suffix) {
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
	// 先按 HTML 目錄解析（V2 的圖片寫成 ../assets/...），再驗證仍在發布目錄內。
	SourcePath = RequireUnder(HtmlDirectory / Uri.UnescapeDataString(Relative), SourceRoot);
	return true;
}

string? MapPublishedUrl(Pth SourcePath, string SiteBase, Pth SourceAssets, IReadOnlyDictionary<string, string> DocumentUrls) {
	// 可發布文件和 assets 都有明確的站內網址；其他相對鏈接保留原樣，交由文檔作者決定其語義。
	if (DocumentUrls.TryGetValue(SourcePath.Value, out var DocumentUrl)) {
		return DocumentUrl;
	}
	if (!IsUnder(SourcePath, SourceAssets)) {
		return null;
	}
	if (!IsFile(SourcePath)) {
		throw new Exception($"linked asset does not exist: {SourcePath}");
	}
	var Relative = Path.GetRelativePath(SourceAssets.Value, SourcePath.Value)
		.Replace(Path.DirectorySeparatorChar, Config.UrlPathSeparator);
	return $"{SiteBase}/{Config.AssetsDirectoryName}/{Relative}";
}

async Task UpdateArticleCatalog(Pth ArticlesRoot, string Slug, string Id, List<ArticlePage> Pages, CT Ct) {
	// catalog.json 是網站側唯一的機器可讀清單：tools/build-site.mjs 只讀它，
	// 不再自己摸 Mvn 的目錄佈局，故發布佈局再變也不必改網站側。
	// 這裡只寫機器推得出來的欄位；日期、摘要等由人寫在網站倉庫的 articles.meta.json。
	var CatalogPath = ArticlesRoot / Config.CatalogFileName;
	var Entries = new List<ArticleCatalogEntry>();
	if (IsFile(CatalogPath)) {
		await using var Existing = await Read(CatalogPath, Ct);
		var Catalog = JsonSerializer.Deserialize<ArticleCatalog>(await Existing.Text(Ct), Json);
		Entries = Catalog?.Articles ?? new List<ArticleCatalogEntry>();
	}
	Entries.RemoveAll(Entry => string.Equals(Entry.Slug, Slug, StringComparison.OrdinalIgnoreCase));
	foreach (var Page in Pages) {
		Entries.Add(new ArticleCatalogEntry(Slug, Id, Page.ContentLang, Page.DocId, Page.Title, Page.Body, Page.Pdf, Page.Source, Page.Toc));
	}
	Entries.Sort((Left, Right) => string.Compare(
		$"{Left.Slug}/{Left.ContentLang}/{Left.Doc}",
		$"{Right.Slug}/{Right.ContentLang}/{Right.Doc}",
		StringComparison.Ordinal));
	await Mkdir(ArticlesRoot, Ct);
	await Write(CatalogPath, JsonSerializer.Serialize(new ArticleCatalog(Entries), new JsonSerializerOptions(Json) {
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
	public string ManifestSchemaV2 { get; } = "2";
	public string SlugPropertyName { get; } = "Slug";
	public char SlugSeparator { get; } = '-';
	public string TypstExtension { get; } = ".typ";
	public string HtmlExtension { get; } = ".html";
	public string PdfExtension { get; } = ".pdf";
	public string PdfArticleFileName { get; } = "article.pdf";
	// 正文片段檔名。整頁外殼由網站側的產生器組，匯入器只交正文。
	public string BodyFileName { get; } = "body.html";
	// 網站側唯一的機器可讀清單。
	public string CatalogFileName { get; } = "catalog.json";
	// 一種語言只有一個文檔時，網址不再多一層文檔名。
	public string EmptyDocId { get; } = "";
	// 本站的正文網址前綴；片段裡的同專案互鏈用它寫成站根相對網址。
	public string ArticlesUrlPrefix { get; } = "/articles";
	// 只把這幾級標題收進目錄，並在缺 id 時補錨點。
	public string TocHeadingSelector { get; } = "h2, h3, h4";
	// 標題文字清不出任何字母數字時用的錨點名。
	public string DefaultAnchorName { get; } = "section";
	// 標題末尾的錨點連結；樣式在網站側的 public/assets/site.css。
	public string HeadingAnchorClassName { get; } = "heading-anchor";
	public string HeadingAnchorText { get; } = "#";
	public string DefaultArticleTitle { get; } = "文章";
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
	// V1 帶文件清單；V2 帶目錄清單。未使用的一側在 Mvn 寫出的 JSON 裏是 null。
	public Dictionary<string, PublishedDoc>? SrcDocs { get; init; }
	public Dictionary<string, PublishedDoc>? GeneratedDocs { get; init; }
	public List<PublishedDir>? SrcDirs { get; init; }
	public List<PublishedDir>? GeneratedDirs { get; init; }
	[JsonExtensionData]
	public Dictionary<string, JsonElement> ExtensionData { get; init; } = new();
}

record PublishedDoc {
	public string Lang { get; init; } = "";
}

record PublishedDir {
	public string Path { get; init; } = "";
	public string Lang { get; init; } = "";
	public string Generator { get; init; } = "";
	public PublishedGeneratorOptions? GeneratorOptions { get; init; }
	public List<PublishedDocEntry>? Docs { get; init; }
	public string? EntryPoint { get; init; }
}

record PublishedGeneratorOptions {
	// 只用到 From：生成目錄的入口清單從來源目錄繼承。其餘欄位是 Mvn 的生成器參數，匯入器不關心。
	public string From { get; init; } = "";
}

record PublishedDocEntry {
	public string File { get; init; } = "";
	public Dictionary<string, string>? Inputs { get; init; }
}

record PublishedDocument(string Lang, Pth TypSource, Pth HtmlSource, Pth PdfSource, string PdfRelative, string SourceRelative, string DocId, string BodyRelative);
// 一篇正文在網站側需要的全部索引資料；記錄的是相對於 /articles/<slug>/ 的路徑，不是發布副本的路徑。
record ArticlePage(string ContentLang, string DocId, string Title, string Body, string Pdf, string Source, List<TocEntry> Toc);
record ArticleCatalog(List<ArticleCatalogEntry> Articles);
record ArticleCatalogEntry(string Slug, string Id, string ContentLang, string Doc, string Title, string Body, string Pdf, string Source, List<TocEntry> Toc);
// 目錄條目。Id 是正文裡標題的錨點，Level 是 heading 的層級（2 到 4）。
record TocEntry(string Id, string Text, int Level);