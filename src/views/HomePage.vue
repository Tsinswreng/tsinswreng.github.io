<script setup lang="ts">
import { onMounted, ref } from "vue";
import SiteLayout from "../components/SiteLayout.vue";
type ArticleEntry = { slug: string; lang: string; title: string; url: string };
const articles = ref<ArticleEntry[]>([]);
onMounted(async () => {
  const response = await fetch("/articles/index.json");
  if (response.ok) articles.value = await response.json() as ArticleEntry[];
});
</script>

<template>
  <SiteLayout>
    <section id="articles" class="home-card">
      <h2>文章</h2>
      <p v-if="articles.length === 0">目前沒有已發布文章。</p>
      <div v-for="article in articles" :key="article.slug + '/' + article.lang" class="article-list-item">
        <h3>{{ article.title }}</h3>
        <p>{{ article.lang }}</p>
        <a class="button-link" :href="article.url">閱讀文章</a>
      </div>
    </section>
    <section id="projects" class="home-card spaced"><h2>專案</h2><p>專案頁面施工中。</p></section>
    <section id="tools" class="home-card spaced"><h2>工具</h2><p>工具頁面施工中。</p></section>
    <section id="about" class="home-card spaced"><h2>關於</h2><p>這裡會放置個人介紹與其他信息。</p></section>
  </SiteLayout>
</template>
