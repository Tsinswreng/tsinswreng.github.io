#metadata((
	_Schema: "2",
	Slug: "disk-junction-migration",

	// 源目錄。單位是目錄，一條等於一棵源碼樹。
	SrcDirs: (
		(
			// 目錄位置，相對於本文件所在目錄。名字與語言無關。
			Path: "zh-Hant",

			// 這棵樹的語言。獨立宣告，不從 Path 推。
			Lang: "zh-Hant",

			// 每個元素都是獨立的編譯入口。
			Docs: (
				(File: "Main.typ"),
			),

			// 主入口。構建不校驗它，只原樣帶進發布索引。
			EntryPoint: "Main.typ",
		),

		// 有英文版時再開一條：
		// (Path: "en", Lang: "en", Docs: ((File: "Main-en.typ"),), EntryPoint: "Main-en.typ"),
	),

	// 生成目錄。獨立一個區塊，源那一塊不必知道它存在。
	GeneratedDirs: (
		(
			Path: "zh-Hans",
			Lang: "zh-Hans",
			Generator: "OpenCC",
			GeneratorOptions: (
				From: "zh-Hant",
				Mode: "t2s",
				// **/ 匹配零層或多層目錄，故頂層與子目錄的 .typ 都含。
				// 圖片在項目根的 assets/，不在這棵樹裏，故不會被當文字轉。
				Include: ("**/*.typ",),
				// 沒有要排除的檔，故為 none。
				Exclude: none,
			),
			// 不重列 Docs：入口與來源一致，含各自的 Inputs。
		),
	),
))<ManifestV2>

#let PubRec = (
	Zhihu: (
		Url: "https://zhuanlan.zhihu.com/p/2075311966801900492",
		Lang: "zh-Hans",
		GitTag: "disk-junction-migration-2026_0826_192319",
	)
)