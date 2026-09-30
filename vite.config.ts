import { fileURLToPath, URL } from "node:url";
import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

// Vite 只負責需要互動的頁面（目前是 clean-disk 的 PDF 閱讀器）。
// 其餘頁面（首頁、文章總覽、單篇入口、正文）由 tools/build-site.mjs 產生靜態 HTML，
// 故不列在這裏。順序是 vite build 先跑，產生器再往 dist/ 補頁面。
//
// bundle 目錄與手寫樣式的 public/assets/ 分開，避免兩者混在同一個網址前綴下。
export default defineConfig({
	plugins: [vue()],
	build: {
		assetsDir: "bundle",
		rollupOptions: {
			input: {
				cleanDisk: fileURLToPath(new URL("./clean-disk/index.html", import.meta.url)),
				cleanDiskPdf: fileURLToPath(new URL("./clean-disk/pdf/index.html", import.meta.url)),
			},
		},
	},
});