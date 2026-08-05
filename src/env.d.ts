/// <reference types="vite/client" />

// pdfjs-dist 的此建置入口沒有隨套件提供 TypeScript 宣告；實際 API 由 PDF.js 在執行期提供。
declare module "pdfjs-dist/build/pdf.mjs";
