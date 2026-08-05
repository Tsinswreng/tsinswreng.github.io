<script setup lang="ts">
import SiteLayout from "../components/SiteLayout.vue";
</script>

<template>
  <SiteLayout>
    <section id="articles" class="home-card">
      <h2>文章</h2>
      <h3>用目錄鏈接讓 C 盤騰出空間</h3>
      <p>介紹如何利用 Windows Junction，把較大的資料夾遷移到其他磁碟。</p>
      <a class="button-link" href="/clean-disk/">閱讀文章</a>
    </section>
    <section id="projects" class="home-card spaced"><h2>專案</h2><p>專案頁面施工中。</p></section>
    <section id="tools" class="home-card spaced"><h2>工具</h2><p>工具頁面施工中。</p></section>
    <section id="about" class="home-card spaced"><h2>關於</h2><p>這裡會放置個人介紹與其他信息。</p></section>
  </SiteLayout>
</template>
