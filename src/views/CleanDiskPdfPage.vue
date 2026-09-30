<script setup lang="ts">
import PdfViewer from "../components/PdfViewer.vue";
import SiteLayout from "../components/SiteLayout.vue";
</script>

<template>
	<SiteLayout heading="用目錄鏈接讓 C 盤騰出空間" subtitle="PDF.js 閱讀器概念驗證。" nav-key="articles" compact>
		<article class="reading pdf-article-shell">
			<header class="reading-head">
				<div class="button-row">
					<a class="button-link" href="/clean-disk/">回到文章</a>
				</div>
			</header>
			<PdfViewer pdf-url="/clean-disk.pdf" title="用目錄鏈接讓 C 盤騰出空間" />
		</article>
	</SiteLayout>
</template>