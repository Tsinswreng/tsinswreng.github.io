import { createApp } from "vue";
import CleanDiskPage from "../views/CleanDiskPage.vue";

// 樣式由 HTML 入口以 /assets/site.css 直接引用，不經 Vite 打包（見 vite.config.ts 的說明）。
createApp(CleanDiskPage).mount("#app");
