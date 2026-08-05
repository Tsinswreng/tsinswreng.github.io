import { fileURLToPath, URL } from "node:url";
import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

// 每一個 input 都是一個獨立的靜態頁面；輸出路徑保留原網址的目錄結構。
export default defineConfig({
  plugins: [vue()],
  build: {
    rollupOptions: {
      input: {
        home: fileURLToPath(new URL("./index.html", import.meta.url)),
        cleanDisk: fileURLToPath(new URL("./clean-disk/index.html", import.meta.url)),
        cleanDiskPdf: fileURLToPath(new URL("./clean-disk/pdf/index.html", import.meta.url)),
      },
    },
  },
});
