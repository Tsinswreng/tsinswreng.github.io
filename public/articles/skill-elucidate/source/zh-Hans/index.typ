#import "../../_Common.typ": *
#show: _Show
#let origin-auto-heading = auto-heading
#import "tsinswreng-elucidate/Body.typ": *



#_Document("skill-elucidate")[

	#title[skill:让AI输出规范易懂的人话]


	#_Outline()


	#P[
		此skill是我个人整理的一套*写作规范*,
		来自对真实AI输出中常见毛病的归纳,
		用来把模型的输出改写成*规范易懂*的人话,
		并能显著*减少AI味*。
		内容涵盖用词表述、行文组织、举例类比、排版等方面,
		适用于AI讲解、教学、写作等场景。
		
		#P[
			此skill开源在
		#link("https://github.com/Tsinswreng/skill-elucidate")。
		使用方式与一些注意要点在#link(<文末>)[文末]。
		本文先展示skill的正文内容,
		正文内容如下:
		]
	]


	#HReset()

	#Body(P: P)


	#HReset()
	\-\-\-\-\-\-\-\-skill正文到此结束\-\-\-\-\-\-\-\-

	#HReset()
	#let H = origin-auto-heading

	#H(label: <文末>)[安装][
		#P[
			找到github仓库中的`SKILL.md`,
			- 简中: #link("https://github.com/Tsinswreng/skill-elucidate/blob/master/Langs/zh-Hans/tsinswreng-elucidate/SKILL.md")
			- 繁中: #link("https://github.com/Tsinswreng/skill-elucidate/blob/master/Langs/zh-Hant/tsinswreng-elucidate/SKILL.md")
			手动放到项目的skill目录下(如`.agent/skills/tsinswreng-elucidate/`)。
			该skill的默认名称是`tsinswreng-elucidate`,
			其中`tsinswreng-`是本人名称,
			充当命名空间,
			无实际意义。
		]
		
		#P[
			您可自行按需更改该skill任何部分的内容,
			不限于名称、描述、正文等,
			反正此skill就是一段自然语言文本。
		]
		
	]

	#H[使用例][
		#P[
			这里展示一个[使用该skill来润色文本]的实例。
			使用的模型是glm-5.2-highspeed。
			以下是未使用此skill时模型输出的一段文字,
			来自在某项目中AI对遇到的一个bug的总结,
			内容完全由模型自己发挥:

		]
		#quote(block: true)[
			#[*OpenCode 版本必须精确 pin(当前 1.18.23)并端到端验证*:
				Docker Hub 的 `openeuler/opencode`
				标签和 npm 的 `opencode-ai`
				是两套版本;
				历史上“版本不低于下限”的策略造成开发/生产漂移,
				token 统计全坏。
				禁止用可变 `latest`。
			]
		]
		
		

		#P[
			可见无约束时,
			AI直接输出的内容非常符合AI的文风,
			且看起来不是这么清晰易懂。
			随后要求大模型按要求改写润色,
			人工发送以下提示词给大模型:
			#quote(block: true)[
				看elucidate skill, 改写这段话。
			]
		]

		#P[
			改写后的一次产出:
		]

		#quote(block: true)[
			#[
				OpenCode 的版本必须固定到具体的版本号,
				当前固定的版本是 1.18.23;
				固定之后还要对版本做端到端验证。
				这条规定的依据如下:
				1. #[Docker Hub 上 `openeuler/opencode`
						镜像的标签与 npm 上 `opencode-ai`
						包的版本号是两套互不相干的版本体系,
						确认版本时必须两边都查。
					]
				2. #[历史上采用过「版本不低于下限」的策略,
						也就是只要求版本号达到某个下限,
						不锁定具体版本。
						这个策略造成开发环境与生产环境所用的版本发生漂移,
						最终 token 统计功能完全损坏。
					]
				3. #[`latest`
						是可变标签,
						`latest` 指向的版本会随时间变化,
						因此禁止使用 `latest`。
					]
			]
		]
	]
	
	#P[
		可见,
		该skill还是有一定效果的。
	]


	#H[几个注意点][
		+ #[#P[
					建议先让AI直接输出,
					再让AI按照skill修改。
					相较于直接让AI按照skill规则一次性输出完,
					这样做的话,
					「初始输出」与「按skill修改润色」被人为分成了两个任务,
					效果往往会更好。
				]

				#P[
					原因在于模型的注意力有限。
					生成时,
					模型的注意力要分配到上下文的全部内容上,
					上下文里的规约越多,
					每条规约分到的注意力越少,
					模型越容易漏掉上下文中间的内容。
					所以分两遍做:
					第一遍让模型写出初稿,
					第二遍让模型拿规约逐条对照初稿修改。
					这样第二遍只有对照与修改一件事,
					每条规约才更容易被遵守执行。
				]
			]

		+ #P[
				此skill不是银弹,
				产出的文本的品质模型能力有关。
				一次性修改未必能使您完全满意,
				可适当放低期待,
				让AI按skill多轮对照再修改,
				不必指望AI能一次性改好。
				通常每轮润色修改后的产出品质都会有提升。
			]
	]

]
