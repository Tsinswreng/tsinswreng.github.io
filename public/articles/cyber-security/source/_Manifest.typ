#metadata((
	_Schema: "2",
	Slug: "cyber-security",

	// 源目錄。單位是目錄，一條等於一棵源碼樹。
	SrcDirs: (
		(
			// 目錄位置。正文早在 2026-09 就按語言收進 zh-Hant/ 了，
			// 舊 manifest 卻仍寫成項目根下的檔名，故 check 一直報
			// "source document does not exist: hvv-attack.typ"。
			Path: "zh-Hant",

			// 這棵樹的語言。獨立宣告，不從 Path 推。
			Lang: "zh-Hant",

			// 每個元素都是獨立的編譯入口。
			// 目前只列網站已發布的兩篇；拆篇系列的
			// recon／internal-ad／web-exploit／privilege-escalation
			// 與 zh-Hant/index.typ 尚未列入，要不要發布另行決定。
			Docs: (
				(File: "hvv-attack.typ"),
				(File: "credentials.typ"),
			),

			// 主入口。構建不校驗它，只原樣帶進發布索引。
			EntryPoint: "hvv-attack.typ",
		),
	),
))<ManifestV2>