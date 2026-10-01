<script setup lang="ts">
// 這是舊頁面（clean-disk 與其 PDF 閱讀器）用的站殼。
// 由產生器生成的頁面用的是 tools/build-site.mjs 裏的同一套標記與 class，
// 兩邊都以 site.config.mjs 為資料來源，故導航與文案不會分家。
import { defaultLocale, languageNames, localeOrder, localePrefix, nav, ui } from "../../site.config.mjs";

type Strings = (typeof ui)[typeof defaultLocale];

const props = withDefaults(
	defineProps<{ locale?: string; heading?: string; subtitle?: string; navKey?: string; compact?: boolean }>(),
	{ locale: defaultLocale, navKey: "home", compact: false },
);

const table = ui as Record<string, Strings>;
const strings: Strings = table[props.locale] ?? table[defaultLocale];
const names = languageNames as Record<string, string>;

function navPath(key: string): string {
	const prefix = localePrefix(props.locale);
	if (key === "home") {
		return `${prefix}/`;
	}
	if (key === "articles") {
		return `${prefix}/articles/`;
	}
	return `${prefix}/${key}/`;
}

function homePath(code: string): string {
	return `${localePrefix(code)}/`;
}

function go(direction: "back" | "forward"): void {
	if (direction === "back") {
		history.back();
	}
	else {
		history.forward();
	}
}
</script>

<template>
	<nav class="site-nav" :aria-label="strings.uiLanguage">
		<div class="shell site-nav-inner">
			<a class="brand name" :href="navPath('home')">{{ strings.siteName }}</a>
			<div class="nav-links">
				<a
					v-for="item in nav"
					:key="item.key"
					:href="navPath(item.key)"
					:aria-current="item.key === props.navKey ? 'page' : undefined"
				>{{ strings.nav[item.key as keyof Strings['nav']] }}</a>
			</div>
			<div class="nav-tools">
				<button class="icon-button" type="button" :title="strings.back" :aria-label="strings.back" @click="go('back')">&#9664;</button>
				<button class="icon-button" type="button" :title="strings.forward" :aria-label="strings.forward" @click="go('forward')">&#9654;</button>
				<div class="locale-switch" :lang="props.locale">
					<a
						v-for="code in localeOrder"
						:key="code"
						:href="homePath(code)"
						:hreflang="code"
						:aria-current="code === props.locale ? 'true' : undefined"
					>{{ names[code] }}</a>
				</div>
			</div>
		</div>
	</nav>
	<header class="site-hero" :class="{ 'site-hero--compact': props.compact }">
		<div class="shell">
			<h1>{{ props.heading ?? strings.siteName }}</h1>
			<p v-if="props.subtitle">{{ props.subtitle }}</p>
		</div>
	</header>
	<main class="site-main">
		<div class="shell"><slot /></div>
	</main>
	<footer class="site-footer">
		<p>{{ strings.footerNote }}</p>
		<p>&copy; {{ new Date().getFullYear() }} <span class="name">{{ strings.siteName }}</span></p>
	</footer>
</template>