<script setup lang="ts">
import PdfViewer from "../components/PdfViewer.vue";
import SiteLayout from "../components/SiteLayout.vue";
</script>

<template>
  <SiteLayout heading="用目錄鏈接讓 C 盤騰出空間" subtitle="PDF.js 閱讀器概念驗證。">
    <article class="article-shell pdf-article-shell">
      <header class="article-heading">
        <h2>用目錄鏈接讓 C 盤騰出空間</h2>
        <p>PDF.js 閱讀器概念驗證。</p>
        <p><a href="/clean-disk/">返回文章</a></p>
      </header>
      <PdfViewer pdf-url="/clean-disk.pdf" title="用目錄鏈接讓 C 盤騰出空間" />
    </article>
  </SiteLayout>
</template>
