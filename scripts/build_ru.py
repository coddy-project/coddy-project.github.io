"""Build the Russian static pages from the English page structure.

Run ``python scripts/build_ru.py`` after editing the English pages or the
translations. The generated files are committed so GitHub Pages needs no build;
``python -m unittest discover -s scripts`` checks that they are up to date.
"""

from __future__ import annotations

import html
import json
import re
from html.parser import HTMLParser
from pathlib import Path

from ru_translations import TRANSLATIONS


ROOT = Path(__file__).resolve().parent.parent
PRESERVE = {
    line for line in Path(__file__).with_name("ru_preserve.txt").read_text(encoding="utf-8").splitlines()
    if line and not line.startswith("#")
}
PAGES = {
    "index.html": "ru/index.html",
    "compare/index.html": "ru/compare/index.html",
}
RAW_TAGS = {"script", "style", "pre", "code", "svg"}
# Marks that close a phrase. A fragment starting with one sits right after the
# inline element before it, one starting with a word needs a space there.
CLOSING_PUNCTUATION = tuple(",.;:!?)")
ATTRIBUTE_TRANSLATIONS = {
    "Coddy agent": "Coddy Agent",
    "Coddy console TUI with the model selector open": "Терминальная консоль Coddy с открытым выбором модели",
    "Coddy web UI start screen with the model menu open": "Стартовый экран веб-интерфейса Coddy с открытым меню моделей",
    "Zed with the Coddy thread open in the agent panel": "Zed с сессией Coddy в панели агента",
    "Termux on an Android phone next to the relay's web UI asking to approve a file write on the phone": "Termux на телефоне с Android рядом с веб-интерфейсом ретранслятора, который просит разрешить запись файла на телефоне",
    "Breadcrumb": "Навигационная цепочка",
    "Capabilities": "Возможности",
    "Coddy agent home": "Главная страница Coddy",
    "Coddy surfaces": "Интерфейсы Coddy",
    "Copy Homebrew install command": "Копировать команду установки Homebrew",
    "Copy compose file": "Копировать Compose-файл",
    "Copy deb install commands": "Копировать команды установки deb",
    "Copy docker command": "Копировать команду Docker",
    "Copy install command": "Копировать команду установки",
    "Copy rpm install commands": "Копировать команды установки rpm",
    "Docker install method": "Способ установки через Docker",
    "Install platform": "Платформа установки",
    "Language": "Язык",
    "Linux install method": "Способ установки в Linux",
    "Open menu": "Открыть меню",
    "Play demo: Coddy console TUI, 3:21": "Воспроизвести демо терминальной консоли Coddy, 3:21",
    "Play demo: Coddy on an Android phone in a swarm, 1:47": "Воспроизвести демо Coddy на телефоне с Android в рое узлов, 1:47",
    "Play demo: Coddy inside Zed over ACP, 2:57": "Воспроизвести демо Coddy в Zed через ACP, 2:57",
    "Play demo: Coddy web UI, 2:58": "Воспроизвести демо веб-интерфейса Coddy, 2:58",
    "Site menu": "Меню сайта",
    "macOS install method": "Способ установки в macOS",
    "Latest release on GitHub": "Последний релиз на GitHub",
    "Sitemap": "Карта сайта",
}


def normalize(value: str) -> str:
    return " ".join(html.unescape(value).split())


class TranslateHTML(HTMLParser):
    def __init__(self, page: str):
        super().__init__(convert_charrefs=False)
        self.page = page
        self.parts: list[str] = []
        self.stack: list[str] = []
        self.untranslated: set[str] = set()
        self.used: set[str] = set()

    def handle_decl(self, decl: str) -> None:
        self.parts.append(f"<!{decl}>")

    def handle_comment(self, data: str) -> None:
        self.parts.append(f"<!--{data}-->")

    def localize_tag(self, tag: str, attrs: list[tuple[str, str | None]]) -> str:
        """The tag as written, with its language, readable attributes and asset paths localized.
        A self-closing tag such as <img ... /> takes the same path as an opening one."""
        raw = self.get_starttag_text()
        if tag == "html":
            raw = raw.replace('lang="en"', 'lang="ru"')
        for key, value in attrs:
            if key in {"aria-label", "alt", "title"} and value in ATTRIBUTE_TRANSLATIONS:
                translated = f'{key}="{html.escape(ATTRIBUTE_TRANSLATIONS[value], quote=True)}"'
                # The source may write an apostrophe as it is or as an entity.
                for written in (html.escape(value, quote=True), html.escape(value, quote=False).replace('"', "&quot;")):
                    raw = raw.replace(f'{key}="{written}"', translated)
        if self.page == "index.html":
            raw = re.sub(r'((?:href|src|data-video)=")(assets/|styles\.css)', r'\1/\2', raw)
        return raw

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.parts.append(self.localize_tag(tag, attrs))
        self.stack.append(tag)

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.parts.append(self.localize_tag(tag, attrs))

    def handle_endtag(self, tag: str) -> None:
        self.parts.append(f"</{tag}>")
        if tag in self.stack:
            self.stack = self.stack[: len(self.stack) - 1 - self.stack[::-1].index(tag)]

    def handle_data(self, data: str) -> None:
        if any(tag in RAW_TAGS for tag in self.stack):
            self.parts.append(data)
            return
        source = normalize(data)
        if not source:
            self.parts.append(data)
            return
        translated = TRANSLATIONS.get(source)
        if translated is None and source not in PRESERVE:
            self.untranslated.add(source)
            self.parts.append(data)
            return
        self.used.add(source)
        if translated is None:
            self.parts.append(data)
            return
        leading = re.match(r"\s*", data).group()
        trailing = re.search(r"\s*$", data).group()
        # Russian word order moves punctuation across an inline element such as
        # <code>, so the English spacing around the fragment does not always fit.
        if translated.startswith(CLOSING_PUNCTUATION):
            leading = ""
        elif not leading and source.startswith(CLOSING_PUNCTUATION):
            leading = " "
        self.parts.append(leading + html.escape(translated, quote=False) + trailing)

    def handle_entityref(self, name: str) -> None:
        self.parts.append(f"&{name};")

    def handle_charref(self, name: str) -> None:
        self.parts.append(f"&#{name};")

    def handle_pi(self, data: str) -> None:
        self.parts.append(f"<?{data}>")


def set_meta(page: str, *, title: str, description: str, url: str) -> str:
    replacements = {
        r"<title>.*?</title>": f"<title>{html.escape(title)}</title>",
        r'<meta name="description" content="[^"]*" />':
            f'<meta name="description" content="{html.escape(description, quote=True)}" />',
        r'<link rel="canonical" href="[^"]*" />':
            f'<link rel="canonical" href="{url}" />',
        r'<meta property="og:locale" content="[^"]*" />':
            '<meta property="og:locale" content="ru_RU" />',
        r'<meta property="og:title" content="[^"]*" />':
            f'<meta property="og:title" content="{html.escape(title, quote=True)}" />',
        r'<meta property="og:description" content="[^"]*" />':
            f'<meta property="og:description" content="{html.escape(description, quote=True)}" />',
        r'<meta property="og:url" content="[^"]*" />':
            f'<meta property="og:url" content="{url}" />',
        r'<meta name="twitter:title" content="[^"]*" />':
            f'<meta name="twitter:title" content="{html.escape(title, quote=True)}" />',
        r'<meta name="twitter:description" content="[^"]*" />':
            f'<meta name="twitter:description" content="{html.escape(description, quote=True)}" />',
    }
    for pattern, replacement in replacements.items():
        page, count = re.subn(pattern, lambda _: replacement, page, count=1, flags=re.S)
        if count != 1:
            raise ValueError(f"Could not replace {pattern}")
    return page


def localize(page: str, source: str) -> str:
    is_compare = source.startswith("compare/")
    en_path = "/compare/" if is_compare else "/"
    ru_path = "/ru/compare/" if is_compare else "/ru/"
    title = (
        "Coddy и другие агентные харнесы - сравнение 2026 года"
        if is_compare else "Coddy Agent - универсальный агент в одном Go-бинарнике"
    )
    description = (
        "Сравнение Coddy с 19 другими агентными харнесами: поставка, интерфейсы, расширяемость, контекст и безопасность."
        if is_compare else
        "Coddy Agent - агентный харнес для distroless: один Go-бинарник с терминальной консолью, ACP для редакторов, "
        "встроенным веб-интерфейсом, шлюзом Telegram, планировщиком cron, ретранслятором роя и удалённым управлением, "
        "а также правилами, навыками, субагентами, хуками, MCP и вашими ключами API."
    )
    page = set_meta(page, title=title, description=description, url="https://coddy.dev" + ru_path)
    page = page.replace(f'href="{en_path}" lang="en" hreflang="en" aria-current="page"',
                        f'href="{en_path}" lang="en" hreflang="en"')
    page = page.replace(f'href="{ru_path}" lang="ru" hreflang="ru"',
                        f'href="{ru_path}" lang="ru" hreflang="ru" aria-current="page"')
    if is_compare:
        page = page.replace('href="/compare/" lang="en"', 'href="@@EN_COMPARE@@" lang="en"')
    page = page.replace('href="/compare/" aria-current="page"', 'href="/ru/compare/" aria-current="page"')
    page = page.replace('href="/compare/"', 'href="/ru/compare/"')
    page = page.replace('href="@@EN_COMPARE@@"', 'href="/compare/"')
    page = page.replace('href="/#', 'href="/ru/#')
    page = page.replace('href="/" lang="en"', 'href="@@EN_HOME@@" lang="en"')
    page = page.replace('href="/"', 'href="/ru/"')
    page = page.replace('href="@@EN_HOME@@"', 'href="/"')
    page = page.replace('btn.textContent = "Copied"', 'btn.textContent = "Скопировано"')
    page = page.replace('btn.textContent = "Copy"', 'btn.textContent = "Копировать"')
    page = page.replace('content="Coddy Agent - distroless-friendly coding agent harness"',
                        'content="Coddy Agent - агентный харнес для distroless"')
    # The English JSON-LD is replaced with a locale-accurate WebPage record.
    structured = {
        "@context": "https://schema.org",
        "@type": "WebPage",
        "@id": "https://coddy.dev" + ru_path + "#webpage",
        "url": "https://coddy.dev" + ru_path,
        "name": title,
        "description": description,
        "inLanguage": "ru",
        "isPartOf": {"@id": "https://coddy.dev/#website"},
    }
    page, count = re.subn(
        r'<script type="application/ld\+json">.*?</script>',
        '<script type="application/ld+json">\n  ' + json.dumps(structured, ensure_ascii=False, indent=2) + '\n  </script>',
        page, count=1, flags=re.S,
    )
    if count != 1:
        raise ValueError("Missing JSON-LD")
    return page


def build(source: str) -> tuple[str, set[str]]:
    """Return the Russian page for an English one and the entries of the
    translation table and of ru_preserve.txt that it used."""
    parser = TranslateHTML(source)
    parser.feed((ROOT / source).read_text(encoding="utf-8"))
    untranslated = sorted(parser.untranslated)
    if untranslated:
        raise ValueError(
            f"{source}: translate these text fragments or add deliberate names to ru_preserve.txt:\n"
            + "\n".join("  " + value for value in untranslated)
        )
    return localize("".join(parser.parts), source), parser.used


def main() -> None:
    for source, target in PAGES.items():
        result, _ = build(source)
        output = ROOT / target
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(result, encoding="utf-8")
        print(f"Built {target}")


if __name__ == "__main__":
    main()
