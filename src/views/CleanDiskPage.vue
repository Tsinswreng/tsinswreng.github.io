<script setup lang="ts">
import SiteLayout from "../components/SiteLayout.vue";
import articleSource from "../content/clean-disk.html?raw";

// 文章原稿保留完整 HTML，頁面只插入其中的 body，避免產生第二個 /clean-disk.html 網址。
const articleHtml = articleSource.match(/<body[^>]*>([\s\S]*)<\/body>/i)?.[1] ?? articleSource;
</script>

<template>
  <SiteLayout heading="用目錄鏈接讓 C 盤騰出空間" subtitle="Windows 磁碟空間整理方法。">
    <article class="article-shell">
      <header class="article-heading">
        <h2>用目錄鏈接讓 C 盤騰出空間</h2>
        <p>Windows 磁碟空間整理方法。</p>
        <p><a class="button-link" href="/clean-disk/pdf/">試用 PDF 閱讀版</a></p>
      </header>
      <div class="article-body" v-html="articleHtml"></div>
    </article>
  </SiteLayout>
</template>
