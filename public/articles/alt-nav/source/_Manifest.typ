#metadata((
	_Schema: "2",
	Slug: "alt-nav",

	// 源目錄。單位是目錄，一條等於一棵源碼樹；這裏兩棵各是一種語言。
	SrcDirs: (
		(
			// 目錄位置，相對於本文件所在目錄。
			Path: "zh-Hant",

			// 這棵樹的語言。獨立宣告，不從 Path 推。
			Lang: "zh-Hant",

			// 每個元素都是獨立的編譯入口。
			Docs: (
				(
					File: "Main.typ",
					// 這篇同時當 GitHub README，故帶一個自訂輸入。
					Inputs: ("IsGithubReadme": "true"),
				),
			),

			// 主入口。構建不校驗它，只原樣帶進發布索引。
			EntryPoint: "Main.typ",
		),
		(
			Path: "en",
			Lang: "en",
			Docs: (
				(File: "Main-en.typ"),
			),
			EntryPoint: "Main-en.typ",
		),
	),

	// 生成目錄。獨立一個區塊，源那一塊不必知道它存在。
	GeneratedDirs: (
		(
			Path: "zh-Hans",
			Lang: "zh-Hans",
			Generator: "OpenCC",
			GeneratorOptions: (
				// 只由繁體版生成簡體版，英文版不參與。
				From: "zh-Hant",
				Mode: "t2s",
				// 鍵盤圖的繪製源 Keyboard.typ 在項目根，
				// 不在這棵樹裏，故不會被當文字轉。
				Include: ("**/*.typ",),
				Exclude: none,
			),
		),
	),
))<ManifestV2>