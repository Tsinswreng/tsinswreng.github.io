#metadata((
	_Schema: "2",
	Slug: "skill-concept-chain",

	// 源目錄。單位是目錄，一條等於一棵源碼樹。
	SrcDirs: (
		(
			// 目錄位置，相對於本文件所在目錄。
			Path: "zh-Hant",

			// 這棵樹的語言。獨立宣告，不從 Path 推。
			Lang: "zh-Hant",

			// 每個元素都是獨立的編譯入口。
			Docs: (
				(File: "index.typ"),
			),

			// 主入口。構建不校驗它，只原樣帶進發布索引。
			EntryPoint: "index.typ",
		),
	),

	// 本項目只有繁體一版，故沒有 GeneratedDirs。
	// 草稿（Meiosis.typ、_ConceptChain.typ 等）留在項目根，
	// 不被當成編譯入口，也不必跟着語言目錄走；
	// index.typ 用 read("../Meiosis.typ") 取草稿原文。
))<ManifestV2>