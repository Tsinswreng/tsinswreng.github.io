#import "../../_Common.typ": *
#show: _Show
#let origin-auto-heading = auto-heading
#import "tsinswreng-elucidate/Body.typ": *



#_Document("skill-elucidate")[

	#title[skill:讓AI輸出規範易懂的人話]


	#_Outline()


	#P[
		此skill是我個人整理的一套*寫作規範*,
		來自對真實AI輸出中常見毛病的歸納,
		用來把模型的輸出改寫成*規範易懂*的人話,
		並能顯著*減少AI味*。
		內容涵蓋用詞表述、行文組織、舉例類比、排版等方面,
		適用于AI講解、教學、寫作等場景。
		
		#P[
			此skill開源在
		#link("https://github.com/Tsinswreng/skill-elucidate")。
		使用方式與一些注意要點在#link(<文末>)[文末]。
		本文先展示skill的正文內容,
		正文內容如下:
		]
	]


	#HReset()

	#Body(P: P)


	#HReset()
	\-\-\-\-\-\-\-\-skill正文到此結束\-\-\-\-\-\-\-\-

	#HReset()
	#let H = origin-auto-heading

	#H(label: <文末>)[安裝][
		#P[
			找到github倉庫中的`SKILL.md`,
			- 簡中: #link("https://github.com/Tsinswreng/skill-elucidate/blob/master/Langs/zh-Hans/tsinswreng-elucidate/SKILL.md")
			- 繁中: #link("https://github.com/Tsinswreng/skill-elucidate/blob/master/Langs/zh-Hant/tsinswreng-elucidate/SKILL.md")
			手動放到項目的skill目錄下(如`.agent/skills/tsinswreng-elucidate/`)。
			該skill的默認名稱是`tsinswreng-elucidate`,
			其中`tsinswreng-`是本人名稱,
			充當命名空間,
			無實際意義。
		]
		
		#P[
			您可自行按需更改該skill任何部分的內容,
			不限于名稱、描述、正文等,
			反正此skill就是一段自然語言文本。
		]
		
	]

	#H[使用例][
		#P[
			這裏展示一個[使用該skill來潤色文本]的實例。
			使用的模型是glm-5.2-highspeed。
			以下是未使用此skill時模型輸出的一段文字,
			來自在某項目中AI對遇到的一個bug的總結,
			內容完全由模型自己發揮:

		]
		#quote(block: true)[
			#[*OpenCode 版本必須精確 pin(當前 1.18.23)並端到端驗證*:
				Docker Hub 的 `openeuler/opencode`
				標籤和 npm 的 `opencode-ai`
				是兩套版本;
				歷史上“版本不低於下限”的策略造成開發/生產漂移,
				token 統計全壞。
				禁止用可變 `latest`。
			]
		]
		
		

		#P[
			可見無約束時,
			AI直接輸出的內容非常符合AI的文風,
			且看起來不是這麼清晰易懂。
			隨後要求大模型按要求改寫潤色,
			人工發送以下提示詞給大模型:
			#quote(block: true)[
				看elucidate skill, 改寫這段話。
			]
		]

		#P[
			改寫後的一次產出:
		]

		#quote(block: true)[
			#[
				OpenCode 的版本必須固定到具體的版本號,
				當前固定的版本是 1.18.23;
				固定之後還要對版本做端到端驗證。
				這條規定的依據如下:
				1. #[Docker Hub 上 `openeuler/opencode`
						鏡像的標籤與 npm 上 `opencode-ai`
						包的版本號是兩套互不相干的版本體系,
						確認版本時必須兩邊都查。
					]
				2. #[歷史上採用過「版本不低於下限」的策略,
						也就是只要求版本號達到某個下限,
						不鎖定具體版本。
						這個策略造成開發環境與生產環境所用的版本發生漂移,
						最終 token 統計功能完全損壞。
					]
				3. #[`latest`
						是可變標籤,
						`latest` 指向的版本會隨時間變化,
						因此禁止使用 `latest`。
					]
			]
		]
	]
	
	#P[
		可見,
		該skill還是有一定效果的。
	]


	#H[幾個注意點][
		+ #[#P[
					建議先讓AI直接輸出,
					再讓AI按照skill修改。
					相較於直接讓AI按照skill規則一次性輸出完,
					這樣做的話,
					「初始輸出」與「按skill修改潤色」被人爲分成了兩個任務,
					效果往往會更好。
				]

				#P[
					原因在于模型的注意力有限。
					生成時,
					模型的注意力要分配到上下文的全部內容上,
					上下文裏的規約越多,
					每條規約分到的注意力越少,
					模型越容易漏掉上下文中間的內容。
					所以分兩遍做:
					第一遍讓模型寫出初稿,
					第二遍讓模型拿規約逐條對照初稿修改。
					這樣第二遍只有對照與修改一件事,
					每條規約才更容易被遵守執行。
				]
			]

		+ #P[
				此skill不是銀彈,
				產出的文本的品質模型能力有關。
				一次性修改未必能使您完全滿意,
				可適當放低期待,
				讓AI按skill多輪對照再修改,
				不必指望AI能一次性改好。
				通常每輪潤色修改後的產出品質都會有提升。
			]
	]

]
