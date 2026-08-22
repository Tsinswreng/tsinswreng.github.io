/* 
cd M:\_\Code\_Tvs\_Mvn

New-Item -ItemType Directory -Force AltNav/assets

typst compile `
  --root . `
  --format png `
  --ppi 300 `
  AltNav/Keyboard.typ `
  AltNav/assets/Keyboard_AltNav.gen.png

typst compile `
  --root . `
  --format svg `
  AltNav/Keyboard.typ `
  AltNav/assets/Keyboard_AltNav.gen.svg
 */
#import "../_Common.typ": *

#let Keyboard_AltNav = [
	#set text(size: 0.39cm)
	#let BaseWidth = 3em
	#let BaseHeight = 3em
	#let BaseGutter = 0.2em
	#let Radius = 0.2em
	#let ChangedKeyFill = rgb("#00067f")
	#let U(n) = BaseWidth * n + BaseGutter * (n - 1)
	#let KRect(
		width: U(1),
		fill: ColorBack,
		Cont,
	) = {
		rect(
			width: width,
			height: BaseHeight,
			radius: Radius,
			stroke: ColorFore,
			fill: fill,
		)[#Cont]
	}
	#let K(
		width: U(1),
		Cont,
	) = {
		set align(center + horizon)
		KRect(width: width)[
			#Cont
		]
	}
	//Key pair
	#let KP(
		width: U(1),
		Normal,
		Shift,
	) = {
		KRect(width: width)[
			#set align(center)
			#Shift \
			#Normal
		]
	}
	
	//Key note
	#let KN(
		width: U(1),
		Normal,
		Shift,
	) = {
		set align(center + horizon)
		KRect(width: width,
		fill: ChangedKeyFill
		)[
			#place(top+right)[
				#set text(
					red,
				)
				#Shift \
			]
			#Normal
		]
	}

	#let RowEsc = grid(
		columns: 16,
		column-gutter: BaseGutter,
		K[`Esc`],
		K[`F1`],
		K[`F2`],
		K[`F3`],
		K[`F4`],
		K[`F5`],
		K[`F6`],
		K[`F7`],
		K[`F8`],
		K[`F9`],
		K[`F10`],
		K[`F11`],
		K[`F12`],
		K[`PrtSc`],
		K[`Ins`],
		K[`Del`],
	)

	#let RowGrave = grid(
		columns: (auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto),
		column-gutter: BaseGutter,
		KP[#"`"][`~`],
		KP[`1`][`!`],
		KP[`2`][`@`],
		KP[`3`][`#`],
		KP[`4`][`$`],
		KP[`5`][`%`],
		KP[`6`][`^`],
		KP[`7`][`&`],
		KP[`8`][`*`],
		KP[`9`][`(`],
		KP[`0`][`)`],
		KP[`-`][`_`],
		KP[`+`][`=`],
		K(width: U(2))[
			#set text(size: 2em)
			⌫
		],
		K[`Home`],
	)

	#let RowTab = grid(
		columns: (auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto),
		column-gutter: BaseGutter,
		K(width: U(1.5))[`Tab`],
		K[`Q`],
		K[`W`],
		K[`E`],
		K[`R`],
		K[`T`],
		K[`Y`],
		K[`U`],
		KN[`I`][`Home`],
		KN[`O`][`End`],
		K[`P`],
		KP[`[`][`{`],
		KP[`]`][`}`],
		KP(width: U(1.5))[`\`][`|`],
		K[`End`],
	)

	#let RowCaps = grid(
		columns: (auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto),
		column-gutter: BaseGutter,
		K(width: U(1.75))[`Caps`],
		K[`A`],
		K[`S`],
		K[`D`],
		K[`F`],
		K[`G`],
		K[`H`],
		KN[`J`][`←`],
		KN[`K`][`↓`],
		KN[`L`][`↑`],
		KN[`;`][`→`],
		KP[`'`][`"`],
		K(width: U(2.25))[
			#set text(size: 1.5em)
			↵
			//↲
		],
		K[`PgUp`],
	)

	#let RowShift = grid(
		columns: (auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto),
		column-gutter: BaseGutter,
		K(width: U(2.25))[`ShiftL`],
		K[`Z`],
		K[`X`],
		K[`C`],
		K[`V`],
		K[`B`],
		KN[`N`][`←`],
		KN[`M`][`↓`],
		KN[`,`][`↑`],
		KN[`.`][`→`],
		KP[`/`][`?`],
		K(width: U(1.75))[
			`ShiftR`
		],
		K[`↑`],
		K[`PgDn`],
	)
	#let CtrlKeyWidth = U(1.25)
	#let RowCtrl = grid(
		columns: (10),
		column-gutter: BaseGutter,
		K(width: CtrlKeyWidth)[`CtrlL`],
		K(width: CtrlKeyWidth)[`Win`],
		K(width: CtrlKeyWidth)[`AltL`],
		K(width: U(6.25))[`Space`],
		K[`AltR`],
		K[`Fn`],
		K[`CtrlR`],
		K[`←`],
		K[`↓`],
		K[`→`],
	)

	#grid(
		rows: 6,
		row-gutter: BaseGutter,
		RowEsc,
		RowGrave,
		RowTab,
		RowCaps,
		RowShift,
		RowCtrl,
	)

]

#show: _Show
#Keyboard_AltNav
