```sh
dotnet-script Mvn.csx build "skill-elucidate/_Manifest.typ"
```
#metadata((
	_Schema: "2",
	Slug: "skill-elucidate",

	// 源目錄。單位是目錄，一條等於一棵源碼樹。
	SrcDirs: (
		(
			// 目錄位置，相對於本文件所在目錄。名字與語言無關，叫 src 也行。
			Path: "zh-Hant",

			// 這棵樹的語言。獨立宣告，不從 Path 推。
			// 編譯時作為 --input Lang=... 傳給 Typst，也寫進發布索引。
			Lang: "zh-Hant",

			// 每個元素都是獨立的編譯入口，會被傳到 typst compile 中。
			// 其實一般通常只有一個。
			// 沒列在這裏的 .typ 只被 import，不單獨產出文件。
			Docs: (
				(
					File: "index.typ",
					Inputs: (:), // 空字典是 (:)，() 是空數組
				),
			),

			// 主入口。構建不校驗它，只原樣帶進發布索引，
			// 供網站側決定 <語言>/index.html 用哪一篇。愛寫不寫。
			EntryPoint: "index.typ",
		),
	),

	// 生成目錄。獨立一個區塊，源那一塊不必知道它存在。
	// 形狀沿用 GeneratedDocs：產出條目加具名生成器加自由選項包。
	GeneratedDirs: (
		(
			// 生成出來的目錄，產物落在 _Publish/skill-elucidate/zh-Hans/。
			Path: "zh-Hans",

			// 生成結果的語言。同樣獨立宣告。
			Lang: "zh-Hans",

			// 用哪個生成器。加新生成方式只加名字，不改格式。
			Generator: "OpenCC",

			// 該生成器的選項包。
			GeneratorOptions: (
				// 來源目錄。目錄對目錄，不是文件對文件。
				From: "zh-Hant",

				// 轉換方向，t2s 是繁體轉簡體。
				Mode: "t2s",

				// 要轉換的檔，相對來源樹根，* 不跨目錄，**/ 匹配零層或多層目錄。
				// 所以這一條同時包含頂層的 index.typ 與子目錄的
				// tsinswreng-elucidate/Body.typ；只寫 *.typ 會漏掉後者。
				// 構建不判斷文件格式：命中的一律當文字讀入再轉，
				// 所以不要把 .png、.docx 這類二進位檔寫進來。
				Include: ("**/*.typ",),

				// 排除優先於 Include。沒有要排除的檔，故為 none。
				Exclude: none,
			),

			// 生成目錄不重列 Docs：它整棵複製來源目錄，
			// 入口清單與來源一致，含各自的 Inputs，故也不用寫 EntryPoint。
		),
	),
))<ManifestV2>

// #let PubRec = (
// 	Zhihu: (
// 		Url: "https://zhuanlan.zhihu.com/p/2075311966801900492",
// 		Lang: "zh-Hans",
// 		GitTag: "disk-junction-migration-2026_0826_192319",
// 	)
// )