<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from "vue";
import * as pdfjsLib from "pdfjs-dist/build/pdf.mjs";
import workerUrl from "pdfjs-dist/build/pdf.worker.mjs?url";

const props = defineProps<{ pdfUrl: string; title: string }>();
pdfjsLib.GlobalWorkerOptions.workerSrc = workerUrl;

const canvas = ref<HTMLCanvasElement | null>(null);
const canvasArea = ref<HTMLElement | null>(null);
const pageStatus = ref("正在載入 PDF…");
const errorMessage = ref("");
const pdf = ref<any>();
const page = ref(1);
const scale = ref(1);
let renderTask: any;

const pageCount = computed(() => pdf.value?.numPages ?? 0);
const zoom = computed(() => `${Math.round(scale.value * 100)}%`);
const canGoPrevious = computed(() => page.value > 1);
const canGoNext = computed(() => page.value < pageCount.value);
const canZoomOut = computed(() => scale.value > 0.5);
const canZoomIn = computed(() => scale.value < 2.5);

async function renderPage() {
  if (!pdf.value || !canvas.value || !canvasArea.value) return;
  renderTask?.cancel();
  const current = await pdf.value.getPage(page.value);
  const baseViewport = current.getViewport({ scale: 1 });
  const availableWidth = Math.max(280, canvasArea.value.clientWidth - 32);
  const fittedScale = Math.min(availableWidth / baseViewport.width, 1.35);
  const viewport = current.getViewport({ scale: fittedScale * scale.value });
  const outputScale = window.devicePixelRatio || 1;
  const context = canvas.value.getContext("2d", { alpha: false });
  if (!context) throw new Error("無法建立 PDF 繪圖畫面。");
  canvas.value.width = Math.floor(viewport.width * outputScale);
  canvas.value.height = Math.floor(viewport.height * outputScale);
  canvas.value.style.width = `${Math.floor(viewport.width)}px`;
  canvas.value.style.height = `${Math.floor(viewport.height)}px`;
  context.setTransform(outputScale, 0, 0, outputScale, 0, 0);
  renderTask = current.render({ canvasContext: context, viewport });
  await renderTask.promise;
  pageStatus.value = `第 ${page.value}／${pageCount.value} 頁`;
}

async function loadPdf() {
  errorMessage.value = "";
  pageStatus.value = "正在載入 PDF…";
  const response = await fetch(props.pdfUrl, { cache: "no-store" });
  if (!response.ok) throw new Error(`PDF 請求失敗：${response.status}`);
  pdf.value = await pdfjsLib.getDocument({ data: new Uint8Array(await response.arrayBuffer()) }).promise;
  await nextTick();
  await renderPage();
}

async function changePage(amount: number) { page.value += amount; await renderPage(); }
async function changeZoom(amount: number) { scale.value = Math.min(2.5, Math.max(0.5, scale.value + amount)); await renderPage(); }
function showError(error: unknown) { console.error(error); pageStatus.value = "PDF 載入失敗"; errorMessage.value = "PDF 暫時無法載入。"; }
function handleResize() { void renderPage().catch(showError); }

onMounted(() => { void loadPdf().catch(showError); window.addEventListener("resize", handleResize); });
onBeforeUnmount(() => { renderTask?.cancel(); window.removeEventListener("resize", handleResize); });
</script>

<template>
  <section class="pdf-viewer" :aria-label="`${title} PDF 閱讀器`">
    <div class="pdf-toolbar">
      <div class="pdf-page-controls" aria-label="頁面控制">
        <button class="pdf-button" :disabled="!canGoPrevious" @click="changePage(-1)">上一頁</button>
        <span class="pdf-page-status" aria-live="polite">{{ pageStatus }}</span>
        <button class="pdf-button" :disabled="!canGoNext" @click="changePage(1)">下一頁</button>
      </div>
      <div class="pdf-zoom-controls" aria-label="縮放控制">
        <button class="pdf-button" aria-label="縮小" :disabled="!canZoomOut" @click="changeZoom(-0.2)">－</button>
        <span class="pdf-zoom-status">{{ zoom }}</span>
        <button class="pdf-button" aria-label="放大" :disabled="!canZoomIn" @click="changeZoom(0.2)">＋</button>
      </div>
    </div>
    <div ref="canvasArea" class="pdf-canvas-area">
      <canvas ref="canvas" class="pdf-canvas"></canvas>
      <template v-if="errorMessage"><p class="pdf-error">{{ errorMessage }}</p><button class="pdf-button pdf-retry" @click="loadPdf().catch(showError)">重新載入</button></template>
    </div>
  </section>
</template>
