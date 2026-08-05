<script setup lang="ts">
withDefaults(defineProps<{ heading?: string; subtitle?: string }>(), {
  heading: "Tsinswreng 的網站",
  subtitle: "文章、工具與專案整理。",
});
</script>

<template>
  <nav class="site-nav" aria-label="全站導航">
    <div class="site-nav-inner">
      <a class="brand" href="/">Tsinswreng</a>
      <div class="nav-links">
        <a href="/">首頁</a>
        <a href="/#articles">文章</a>
        <a href="/#projects">專案</a>
        <a href="/#tools">工具</a>
        <a href="/#about">關於</a>
      </div>
    </div>
  </nav>
  <header class="site-hero">
    <div class="site-hero-inner">
      <h1>{{ heading }}</h1>
      <p>{{ subtitle }}</p>
    </div>
  </header>
  <main class="site-main"><slot /></main>
  <footer class="site-footer"><p>© {{ new Date().getFullYear() }} Tsinswreng</p></footer>
</template>
