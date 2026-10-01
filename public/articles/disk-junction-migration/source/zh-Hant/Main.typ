#import "../../_Common.typ": *
#show: _Show
#let Img = ImgPath.with(Base: "DiskJunctionMigration")
//始作于2025-07-19T20:30:18.638+08:00_W29-6

#_Document("DiskJunctionMigration",

)[
	#title[用目錄聯接讓C盤騰出空間]
	
	#H[原理][
		#P[
			此法的原理是將要清理的磁盤中
			占用較大空間的目錄移動到其他盤上,
			再用`mklink /J`命令于原位置建立同名目錄聯接(Junction)。
		]

		#P[
			這樣之後,
			原目錄中實際儲存的內容會在其他磁盤上,
			但不影響正常訪問。
		]

		#H[對比直接移動][
			#P[「先移動,
				再鏈接回原處」的目的,
				是在釋放原磁盤空間的同時,
				保留軟件原本使用的路徑。
			]

			#P[
				若只移動文件夾而不建立目錄聯接,
				依賴原路徑的程序可能無法找到其中的文件,
				從而報錯或不能正常啓動。
			]
		]

	]

	#H[準備工具][
		- #[TreeSize
				- 樹型結構查看目錄大小 圖標見@TreeSize
			]
		- #[PowerToys
				- 用于查看占用文件的進程,
					圖標見@PowerToys
			]

		#P[
			TreeSize和PowerToys都不是必需工具。
			TreeSize只是方便快速找出佔用空間較大的目錄；
			File Locksmith只在文件被進程佔用、
			無法複製或刪除時用於排查；
			若遷移過程沒有提示文件被佔用,
			可以跳過它。
		]


		#figure(
			Img("assets/2025-07-19-20-30-56.png"),
			caption: [TreeSize免費版],
		)<TreeSize>

		#figure(
			Img("assets/2025-07-19-20-33-09.png"),
			caption: [PowerToys],
		)<PowerToys>
	]

	#H[掃盤][
		#P[
			以管理員權限打開TreeSize,
			選中要清的磁盤,
			等待掃描。
			TreeSize會以大小對文件樹做排序,
			方便你挑選欲移動之文件夾。
			掃描結果見@TreeSizeScan。
		]
		#figure(
			Img("assets/2025-07-19-20-35-20.png"),
			caption: [TreeSize掃盤結果],
		)<TreeSizeScan>
	]

	#H[挑選要移動的文件夾][
		#P[
			先從體積較大的文件夾開始查看。
			優先選名稱和用途都能辨認、
			而且屬於同一個軟件或同一個廠商的完整文件夾。
			文件夾的範圍要盡量完整、
			但不能大到把無關的軟件一起包含進來。
		]

		#if false {
			[
				例如,
				如果掃描結果如下：
				```text
				C:/Users/admin/AppData/Roaming/
						Tencent/ -- 9.6G
								QQMusic/ -- 6.5G
										QQMusicCache/ -- 6.1G
										wmpf/ -- 315MB
								WXWork/ -- 3.1G
						Code/ -- 2.2G
								User/ -- 982.8M
				```
				應優先考慮整個`Tencent/`和整個`Code/`。
				如果只想遷移其中一個軟件、
				再考慮單獨遷移`QQMusic/`或`WXWork/`。
				像`Code/User/`這樣位於深層的子文件夾、
				通常不要單獨遷移。
				而整個`C:/Users/admin/AppData/Roaming/`、
				以及更上層的目錄、
				則絕對不要遷移。
			]
		}

		#P[
			簡言之:
			- 選「看得懂的一整盒」
			- 不要只搬盒內的一小格
			- 也*不要*把包含許多其他軟件的共用文件夾整個搬走
			- 不要移動系統目錄、程序目錄或其他用途不明的目錄
		]

		#P[
			*若實在拿不準,
			則可以把完整路徑複製下來再向AI詢問*。
		]

		#P[
			若你覺得這個文件夾太小,
			移完也騰不出幾個 G,
			那也沒關係,
			多搬幾個就是了,
			不用非找一個大塊頭。
		]

		#P[
			本例選擇`Docker`文件夾作為遷移目標。
			完整路徑爲`C:\Program Files\Docker`
			目標文件夾見@DockerFolder。

		]

		#figure(
			Img("assets/2025-07-19-20-55-46.png"),
			caption: [`Program Files\Docker`],
		)<DockerFolder>

	]

	#H[移動][
		#H[(可選)檢查文件佔用情況][
			#P[
				按Windows系統的設計,
				文件資源被其他進程佔用時,
				你無法移動他們。

			]
			#Todo[附圖][]

			#P[
				這裏我們使用PowerToys中內置的工具File Locksmith,
				檢查我們要移動的文件夾是否正在被其他進程占用。
				建議以管理員權限運行。
				(非管理員權限運行時,
				點擊刷新按鈕旁的護盾按鈕即可提升到管理員權限運行)
				右鍵入口見@FileLocksmithMenu，
			]

			#figure(
				Img("assets/2025-07-19-20-58-39.png"),
				caption: [右鍵菜單-使用File Locksmith解鎖],
			)<FileLocksmithMenu>
			#figure(
				Img("assets/2025-07-19-21-00-37.png"),
				caption: [File Locksmith檢測結果],
			)<FileLocksmithResult>
			#P[
				如@FileLocksmithResult,
				該文件夾正在被explorer.exe使用中。
				但explorer是Windows上的文件資源管理器,
				一般不影響後續的移動。
				則不管。
			]

			#P[
				若有其他進程佔用,
				但你又拿不準能不能關閉進程,
				則不建議繼續。
				換個目錄再試。
			]
		]

		#H[挑選放置目的地][
			#P[
				在空閒磁盤上找一塊地方作遷移目的地。
				筆者個人習慣 使 目的地的目錄結構 與 原位置 保持一致,
				這樣對應起來較方便。
			]

			#P[
				此例中,
				待遷移的`Docker`文件夾當前位置在`C:\Program Files\`目錄下。
				筆者的E盤剩餘空間較多,
				則我們可以將他移動到`E:\Program Files\`下。
			]
		]

		#H[複製待遷移文件夾至目的地][
			#P[
				*⚠️注意:
				不要直接剪切粘貼。保險起見最好先複製⚠️*
			]

			#P[
				若複製過程出現進程占用,
				則回到File Locksmith的步驟重新檢查
			]

			#P[
				若複製過程出現錯誤(如報錯xxx文件爲系統文件等),
				建議您停止嘗試當前目標。
			]
			#Todo[附圖][

			]

			#P[
				複製待遷移文件夾至目的地
				操作示例見@CopyDocker。
			]
			#figure(
				Img("assets/2025-07-19-21-16-29.png"),
				caption: [複製Docker文件夾],
			)<CopyDocker>

			#P[
				複製成功之後,
				檢查複製是否完整。
			]

			#P[
				對于原文件夾與複製的文件夾
				分別打開屬性(可選中後按快捷鍵Alt+回車),
				檢查大小(字節數)和包含的文件及子文件夾數量是否一致.
				若一致,
				我們即可認爲他複製成功了,
				不需要嚴格校驗散列值
				大小比對示例見@CopySizeCompare。
			]
			#figure(
				Img("assets/2025-07-19-21-23-26.png"),
				caption: [複製後大小比對],
			)<CopySizeCompare>
		]

		#H[刪除原文件夾][
			#P[
				複製成功後,
				我們即可刪除原文件夾。
				此例中,
				我們把`C:\Program Files\Docker`正確複製到
				E盤的`E:\Program Files\Docker`後,
				即可刪除原C盤上的`Docker`文件夾。
			]

			#P[
				直接刪除後文件夾通常會被放入回收站,
				但我們已經成功複製了一份到空間磁盤,
				則在這裏我們採用徹底刪除。
				打開右鍵菜單,
				按住Shift並點擊刪除即可不放入回收站徹底刪除(或使用快捷鍵Shift+Del)
				操作示例見@DeleteDocker。
			]
			#figure(
				Img("assets/2025-07-19-21-25-23.png"),
				caption: [刪除原文件夾],
			)<DeleteDocker>

			#P[
				前面步驟的複製如果成功不報錯且內容完整,
				一般情況下刪除操作也能順利進行。
			]

			// 若您仍不幸在刪除時遇到錯誤,
			// 建議您將副本遷回合併並停止嘗試
		]

		#H[建立目錄聯接(Junction)][
			#H[在源位置以管理員權限打開終端][
				+ #[
						右鍵開始菜單,
						點擊「終端(管理員)」
						Win10界面見@Win10AdminTerminal，
						Win11界面見@Win11AdminTerminal。
						#figure(
							Img("assets/2026-08-25-21-56-42.png"),
							caption: [Win10管理員終端入口],
						)<Win10AdminTerminal>
						#figure(
							Img("assets/2026-08-25-16-16-32.png"),
							caption: [Win11管理員終端入口],
						)<Win11AdminTerminal>

					]
				+ #[複製當前位置路徑
						操作步驟見@CopySourcePathPrompt 及 @CopySourcePathSelected。
						#figure(
							Img("assets/2026-08-25-16-20-41.png"),
							caption: [點擊路徑欄右側空白處],
						)<CopySourcePathPrompt>
						#figure(
							Img("assets/2026-08-25-16-22-12.png"),
							caption: [變成選中狀態後複製],
						)<CopySourcePathSelected>
						在本例中, 當前路徑在`C:\Program Files`
					]
				+ #[在終端中切換到複製的路徑輸入
						```sh
						cd "你複製的路徑"
						```

						在本例中即

						````sh
						cd "C:\Program Files"
						````
						注意要如果路徑兩側沒有引號則應手動加上英文的雙引號
						//在英文雙引號中間按`Ctrl+V`粘貼上剛剛複製的路徑
						操作結果見@CdSourcePath。
						#figure(
							Img("assets/2026-08-25-16-26-18.png"),
							caption: [cd到當前路徑],
						)<CdSourcePath>
					]
				+ #[進入cmd

						#P[
							在終端輸入cmd再按回車,
							確保自己進入了cmd。
							因爲powershell中沒有`mklink`命令,
							故需用cmd。
							操作介面見@EnterCmd。
						]
						#figure(
							Img("assets/2026-08-25-16-29-29.png"),
							caption: [進入cmd],
						)<EnterCmd>
					]

			]
			#H[執行`mklink /J`][
				//+ (可直接在文件資源管理器的地址欄中刪去原有路徑再輸入cmd後按回車)#image("assets/2025-07-19-21-32-48.png")
				+ #[在目的地中選中剛剛複製的文件夾,
						複製該文件夾的路徑。
						在本例中,
						目的文件夾路徑應爲`E:\Program Files\Docker`。

						如果你的電腦系統是Win10:
						操作示例見@Win10CopyDestinationPath。
						#figure(
							Img("assets/2025-07-19-21-36-53.png"),
							caption: [Win10複製路徑],
						)<Win10CopyDestinationPath>

						如果你的電腦系統是Win11:
						操作示例見@Win11CopyDestinationPath。
						#figure(
							Img("assets/2026-08-25-16-34-25.png"),
							caption: [Win11複製路徑],
						)<Win11CopyDestinationPath>

					]
				+ #[在cmd中輸入
						```cmd
						mklink /J "你的源文件夾名" "複製的完整目的地路徑"
						```

						//#image("assets/2025-07-19-21-38-47.png")
						然後按回車執行命令。

						在本例中即
						```cmd
						mklink /J "Docker" "E:\Program Files\Docker"
						```
						命令執行結果見@CreateJunction。
						#figure(
							Img("assets/2025-07-19-21-43-45.png"),
							caption: [建立目錄聯接],
						)<CreateJunction>

						看到輸出爲
						```
						Junction created for Docker <<===>> E:\Program Files\Docker
						```
						這樣就成功了
					]
			]


		]

	]

]


#if false {
	[
		- #[Win10:
				#figure(
					Img("assets/2025-07-19-21-42-03.png"),
					caption: [Win10打開終端],
				)<Win10OpenTerminal>
			]
			- #[Win11:

				]

				先在文件資源管理器中右鍵,
				打開終端

				#figure(
					Img("assets/2026-08-25-15-32-15.png"),
					caption: [],
				)<Win11OpenTerminalMenu>

				點擊窗口頂部向下的箭頭(▼),
				右鍵點擊「命令提示符」彈出菜單,
				再點擊以管理員身分運行
				#figure(
					Img("assets/2026-08-25-15-35-37.png"),
					caption: [],
				)<Win11AdminTerminalMenu>
	]
}
