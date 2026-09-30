#import "../../_Common.typ": *
#show: _Show
#let Img = ImgPath.with(Base: "DiskJunctionMigration")
//始作于2025-07-19T20:30:18.638+08:00_W29-6

#_Document("DiskJunctionMigration",

)[
	#title[用目录联接让C盘腾出空间]
	
	#H[原理][
		#P[
			此法的原理是将要清理的磁盘中
			占用较大空间的目录移动到其他盘上,
			再用`mklink /J`命令于原位置建立同名目录联接(Junction)。
		]

		#P[
			这样之后,
			原目录中实际储存的内容会在其他磁盘上,
			但不影响正常访问。
		]

		#H[对比直接移动][
			#P[「先移动,
				再链接回原处」的目的,
				是在释放原磁盘空间的同时,
				保留软件原本使用的路径。
			]

			#P[
				若只移动文件夹而不建立目录联接,
				依赖原路径的程序可能无法找到其中的文件,
				从而报错或不能正常启动。
			]
		]

	]

	#H[准备工具][
		- #[TreeSize
				- 树型结构查看目录大小 图标见@TreeSize
			]
		- #[PowerToys
				- 用于查看占用文件的进程,
					图标见@PowerToys
			]

		#P[
			TreeSize和PowerToys都不是必需工具。
			TreeSize只是方便快速找出占用空间较大的目录；
			File Locksmith只在文件被进程占用、
			无法复制或删除时用于排查；
			若迁移过程没有提示文件被占用,
			可以跳过它。
		]


		#figure(
			Img("assets/2025-07-19-20-30-56.png"),
			caption: [TreeSize免费版],
		)<TreeSize>

		#figure(
			Img("assets/2025-07-19-20-33-09.png"),
			caption: [PowerToys],
		)<PowerToys>
	]

	#H[扫盘][
		#P[
			以管理员权限打开TreeSize,
			选中要清的磁盘,
			等待扫描。
			TreeSize会以大小对文件树做排序,
			方便你挑选欲移动之文件夹。
			扫描结果见@TreeSizeScan。
		]
		#figure(
			Img("assets/2025-07-19-20-35-20.png"),
			caption: [TreeSize扫盘结果],
		)<TreeSizeScan>
	]

	#H[挑选要移动的文件夹][
		#P[
			先从体积较大的文件夹开始查看。
			优先选名称和用途都能辨认、
			而且属于同一个软件或同一个厂商的完整文件夹。
			文件夹的范围要尽量完整、
			但不能大到把无关的软件一起包含进来。
		]

		#if false {
			[
				例如,
				如果扫描结果如下：
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
				应优先考虑整个`Tencent/`和整个`Code/`。
				如果只想迁移其中一个软件、
				再考虑单独迁移`QQMusic/`或`WXWork/`。
				像`Code/User/`这样位于深层的子文件夹、
				通常不要单独迁移。
				而整个`C:/Users/admin/AppData/Roaming/`、
				以及更上层的目录、
				则绝对不要迁移。
			]
		}

		#P[
			简言之:
			- 选「看得懂的一整盒」
			- 不要只搬盒内的一小格
			- 也*不要*把包含许多其他软件的共用文件夹整个搬走
			- 不要移动系统目录、程序目录或其他用途不明的目录
		]

		#P[
			*若实在拿不准,
			则可以把完整路径复制下来再向AI询问*。
		]

		#P[
			若你觉得这个文件夹太小,
			移完也腾不出几个 G,
			那也没关系,
			多搬几个就是了,
			不用非找一个大块头。
		]

		#P[
			本例选择`Docker`文件夹作为迁移目标。
			完整路径为`C:\Program Files\Docker`
			目标文件夹见@DockerFolder。

		]

		#figure(
			Img("assets/2025-07-19-20-55-46.png"),
			caption: [`Program Files\Docker`],
		)<DockerFolder>

	]

	#H[移动][
		#H[(可选)检查文件占用情况][
			#P[
				按Windows系统的设计,
				文件资源被其他进程占用时,
				你无法移动他们。

			]
			#Todo[附图][]

			#P[
				这里我们使用PowerToys中内置的工具File Locksmith,
				检查我们要移动的文件夹是否正在被其他进程占用。
				建议以管理员权限运行。
				(非管理员权限运行时,
				点击刷新按钮旁的护盾按钮即可提升到管理员权限运行)
				右键入口见@FileLocksmithMenu，
			]

			#figure(
				Img("assets/2025-07-19-20-58-39.png"),
				caption: [右键菜单-使用File Locksmith解锁],
			)<FileLocksmithMenu>
			#figure(
				Img("assets/2025-07-19-21-00-37.png"),
				caption: [File Locksmith检测结果],
			)<FileLocksmithResult>
			#P[
				如@FileLocksmithResult,
				该文件夹正在被explorer.exe使用中。
				但explorer是Windows上的文件资源管理器,
				一般不影响后续的移动。
				则不管。
			]

			#P[
				若有其他进程占用,
				但你又拿不准能不能关闭进程,
				则不建议继续。
				换个目录再试。
			]
		]

		#H[挑选放置目的地][
			#P[
				在空闲磁盘上找一块地方作迁移目的地。
				笔者个人习惯 使 目的地的目录结构 与 原位置 保持一致,
				这样对应起来较方便。
			]

			#P[
				此例中,
				待迁移的`Docker`文件夹当前位置在`C:\Program Files\`目录下。
				笔者的E盘剩余空间较多,
				则我们可以将他移动到`E:\Program Files\`下。
			]
		]

		#H[复制待迁移文件夹至目的地][
			#P[
				*⚠️注意:
				不要直接剪切粘贴。保险起见最好先复制⚠️*
			]

			#P[
				若复制过程出现进程占用,
				则回到File Locksmith的步骤重新检查
			]

			#P[
				若复制过程出现错误(如报错xxx文件为系统文件等),
				建议您停止尝试当前目标。
			]
			#Todo[附图][

			]

			#P[
				复制待迁移文件夹至目的地
				操作示例见@CopyDocker。
			]
			#figure(
				Img("assets/2025-07-19-21-16-29.png"),
				caption: [复制Docker文件夹],
			)<CopyDocker>

			#P[
				复制成功之后,
				检查复制是否完整。
			]

			#P[
				对于原文件夹与复制的文件夹
				分别打开属性(可选中后按快捷键Alt+回车),
				检查大小(字节数)和包含的文件及子文件夹数量是否一致.
				若一致,
				我们即可认为他复制成功了,
				不需要严格校验散列值
				大小比对示例见@CopySizeCompare。
			]
			#figure(
				Img("assets/2025-07-19-21-23-26.png"),
				caption: [复制后大小比对],
			)<CopySizeCompare>
		]

		#H[删除原文件夹][
			#P[
				复制成功后,
				我们即可删除原文件夹。
				此例中,
				我们把`C:\Program Files\Docker`正确复制到
				E盘的`E:\Program Files\Docker`后,
				即可删除原C盘上的`Docker`文件夹。
			]

			#P[
				直接删除后文件夹通常会被放入回收站,
				但我们已经成功复制了一份到空间磁盘,
				则在这里我们采用彻底删除。
				打开右键菜单,
				按住Shift并点击删除即可不放入回收站彻底删除(或使用快捷键Shift+Del)
				操作示例见@DeleteDocker。
			]
			#figure(
				Img("assets/2025-07-19-21-25-23.png"),
				caption: [删除原文件夹],
			)<DeleteDocker>

			#P[
				前面步骤的复制如果成功不报错且内容完整,
				一般情况下删除操作也能顺利进行。
			]

			// 若您仍不幸在删除时遇到错误,
			// 建议您将副本迁回合并并停止尝试
		]

		#H[建立目录联接(Junction)][
			#H[在源位置以管理员权限打开终端][
				+ #[
						右键开始菜单,
						点击「终端(管理员)」
						Win10界面见@Win10AdminTerminal，
						Win11界面见@Win11AdminTerminal。
						#figure(
							Img("assets/2026-08-25-21-56-42.png"),
							caption: [Win10管理员终端入口],
						)<Win10AdminTerminal>
						#figure(
							Img("assets/2026-08-25-16-16-32.png"),
							caption: [Win11管理员终端入口],
						)<Win11AdminTerminal>

					]
				+ #[复制当前位置路径
						操作步骤见@CopySourcePathPrompt 及 @CopySourcePathSelected。
						#figure(
							Img("assets/2026-08-25-16-20-41.png"),
							caption: [点击路径栏右侧空白处],
						)<CopySourcePathPrompt>
						#figure(
							Img("assets/2026-08-25-16-22-12.png"),
							caption: [变成选中状态后复制],
						)<CopySourcePathSelected>
						在本例中, 当前路径在`C:\Program Files`
					]
				+ #[在终端中切换到复制的路径输入
						```sh
						cd "你复制的路径"
						```

						在本例中即

						````sh
						cd "C:\Program Files"
						````
						注意要如果路径两侧没有引号则应手动加上英文的双引号
						//在英文双引号中间按`Ctrl+V`粘贴上刚刚复制的路径
						操作结果见@CdSourcePath。
						#figure(
							Img("assets/2026-08-25-16-26-18.png"),
							caption: [cd到当前路径],
						)<CdSourcePath>
					]
				+ #[进入cmd

						#P[
							在终端输入cmd再按回车,
							确保自己进入了cmd。
							因为powershell中没有`mklink`命令,
							故需用cmd。
							操作介面见@EnterCmd。
						]
						#figure(
							Img("assets/2026-08-25-16-29-29.png"),
							caption: [进入cmd],
						)<EnterCmd>
					]

			]
			#H[执行`mklink /J`][
				//+ (可直接在文件资源管理器的地址栏中删去原有路径再输入cmd后按回车)#image("assets/2025-07-19-21-32-48.png")
				+ #[在目的地中选中刚刚复制的文件夹,
						复制该文件夹的路径。
						在本例中,
						目的文件夹路径应为`E:\Program Files\Docker`。

						如果你的电脑系统是Win10:
						操作示例见@Win10CopyDestinationPath。
						#figure(
							Img("assets/2025-07-19-21-36-53.png"),
							caption: [Win10复制路径],
						)<Win10CopyDestinationPath>

						如果你的电脑系统是Win11:
						操作示例见@Win11CopyDestinationPath。
						#figure(
							Img("assets/2026-08-25-16-34-25.png"),
							caption: [Win11复制路径],
						)<Win11CopyDestinationPath>

					]
				+ #[在cmd中输入
						```cmd
						mklink /J "你的源文件夹名" "复制的完整目的地路径"
						```

						//#image("assets/2025-07-19-21-38-47.png")
						然后按回车执行命令。

						在本例中即
						```cmd
						mklink /J "Docker" "E:\Program Files\Docker"
						```
						命令执行结果见@CreateJunction。
						#figure(
							Img("assets/2025-07-19-21-43-45.png"),
							caption: [建立目录联接],
						)<CreateJunction>

						看到输出为
						```
						Junction created for Docker <<===>> E:\Program Files\Docker
						```
						这样就成功了
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
					caption: [Win10打开终端],
				)<Win10OpenTerminal>
			]
			- #[Win11:

				]

				先在文件资源管理器中右键,
				打开终端

				#figure(
					Img("assets/2026-08-25-15-32-15.png"),
					caption: [],
				)<Win11OpenTerminalMenu>

				点击窗口顶部向下的箭头(▼),
				右键点击「命令提示符」弹出菜单,
				再点击以管理员身分运行
				#figure(
					Img("assets/2026-08-25-15-35-37.png"),
					caption: [],
				)<Win11AdminTerminalMenu>
	]
}
