#metadata((
	_Schema: "1",
	Slug: "alt-nav",

	/// 獨立作爲typst編譯入口的文檔
	SrcDocs: (
		"Main.typ": (
			Lang: "zh-Hant",
		),
		"Main-en.typ": (
			Lang: "en",
		),
	),

	GeneratedDocs: (
		"Main-zh-Hans.typ": (
			Lang: "zh-Hans",
			Generator: "OpenCC",
			GeneratorOptions: (
				From: "Main.typ",
				Mode: "t2s",
			),
		),
	),
))<ManifestV1>
