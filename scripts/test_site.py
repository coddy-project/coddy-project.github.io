"""Checks for the site pages. Run them from the repository root:

    python3 -m unittest discover -s scripts

They catch what is easy to miss in review: a Russian page that no longer
matches its English source, translations no page uses, a word the builder glued
to an inline element, typography the site copy avoids, and the sitemap and FAQ
copies of text that also lives on the pages.
"""

from __future__ import annotations

import html
import json
import re
import sys
import unittest
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_ru  # noqa: E402
from ru_translations import TRANSLATIONS  # noqa: E402

ROOT = build_ru.ROOT
RUSSIAN_PAGES = tuple(build_ru.PAGES.values())
SITE_PAGES = (*build_ru.PAGES, *RUSSIAN_PAGES)

# The site copy uses a hyphen in place of both dashes and straight quotes only.
FORBIDDEN_CHARACTERS = {
    "—": "long dash",
    "–": "en dash",
    "«": "guillemet",
    "»": "guillemet",
    "“": "curly quote",
    "”": "curly quote",
    "‘": "curly quote",
    "’": "curly quote",
}
FORBIDDEN_RUSSIAN_WORDS = {
    "агентск": "the adjective for agent is агентный",
}

INLINE = r"(?:code|a|strong|em|kbd)"
GLUED_TO_INLINE = re.compile(rf"</{INLINE}>(?=[^\W\d_])")
SPACE_BEFORE_PUNCTUATION = re.compile(rf"</{INLINE}>\s+(?=[,.;:!?)])")


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def around(text: str, index: int) -> str:
    return " ".join(text[max(0, index - 50):index + 50].split())


def page_title(path: str) -> str:
    return html.unescape(re.search(r"<title>(.*?)</title>", read(path), re.S).group(1))


def json_ld(path: str) -> list:
    blocks = re.findall(r'<script type="application/ld\+json">(.*?)</script>', read(path), re.S)
    return [json.loads(block) for block in blocks]


class FaqParser(HTMLParser):
    """Collects the questions and answers of the landing page FAQ as plain text."""

    def __init__(self) -> None:
        super().__init__()
        self.answers: dict[str, str] = {}
        self.inside = False
        self.question = ""
        self.tag = ""
        self.text: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "section" and ("id", "faq") in attrs:
            self.inside = True
        elif self.inside and tag in ("h3", "p"):
            self.tag, self.text = tag, []

    def handle_endtag(self, tag: str) -> None:
        if tag == "section":
            self.inside = False
        elif self.inside and tag == self.tag:
            text = " ".join("".join(self.text).split())
            if tag == "h3":
                self.question = text
            else:
                self.answers[self.question] = text
            self.tag = ""

    def handle_data(self, data: str) -> None:
        if self.tag:
            self.text.append(data)


class RussianBuildTest(unittest.TestCase):
    def test_committed_pages_match_the_builder(self) -> None:
        for source, target in build_ru.PAGES.items():
            with self.subTest(page=target):
                built, _ = build_ru.build(source)
                self.assertTrue(read(target) == built, f"{target} is out of date, run python3 scripts/build_ru.py")

    def test_attributes_of_self_closing_tags_are_translated(self) -> None:
        # <img ... /> goes through handle_startendtag, which kept the English
        # alt of every poster and of the logo on the Russian page.
        built, _ = build_ru.build("index.html")
        for img in re.findall(r"<img\b[^>]*/>", built):
            alt = re.search(r'alt="([^"]*)"', img)
            if alt and html.unescape(alt.group(1)) in build_ru.ATTRIBUTE_TRANSLATIONS:
                self.fail(f"untranslated alt on the Russian page: {alt.group(1)}")

    def test_every_table_entry_is_used(self) -> None:
        used: set[str] = set()
        for source in build_ru.PAGES:
            used |= build_ru.build(source)[1]
        self.assertEqual(sorted(set(TRANSLATIONS) - used), [], "no page has these fragments, remove the translations")
        self.assertEqual(sorted(build_ru.PRESERVE - used), [], "no page has these names, remove them from ru_preserve.txt")

    def test_table_entries_are_normalized(self) -> None:
        for source, translation in TRANSLATIONS.items():
            with self.subTest(source=source):
                self.assertEqual(source, build_ru.normalize(source), "the builder never matches a key like this")
                self.assertTrue(translation, "empty translation")
                self.assertEqual(translation, translation.strip())
        self.assertEqual(sorted(build_ru.PRESERVE & set(TRANSLATIONS)), [], "a name is both kept and translated")


class LayoutTest(unittest.TestCase):
    def test_copy_button_does_not_cover_the_command(self) -> None:
        # The Copy button sits over the top right corner of each command block,
        # which reserves room for it: beside the command, wide enough for the
        # widest label of the page's language, or on a phone a row above it.
        # Копировать and Скопировано are wider than Copy and Copied, and the
        # phone rule once cut the room to 52px, so the button covered the end
        # of the command.
        css = read("styles.css")
        rooms = {
            "index.html": re.search(r"\n\.install-code \{[^}]*--copy-room: (\d+)px", css),
            "ru/index.html": re.search(r'html\[lang="ru"\] \.install-code \{[^}]*--copy-room: (\d+)px', css),
        }
        for path, room in rooms.items():
            with self.subTest(page=path):
                self.assertIsNotNone(room, "the command blocks reserve no room for the Copy label")
                page = read(path)
                labels = re.findall(r'class="install-copy"[^>]*>([^<]+)<', page) + re.findall(r'btn\.textContent = "([^"]+)"', page)
                widest = max(len(label) for label in labels)
                # about 7.5px a letter at 12px, 20px of padding, the border and the 8px inset
                self.assertGreaterEqual(int(room.group(1)), round(widest * 7.5 + 30))
        row = re.search(r"\n\.install-code \{[^}]*--copy-row: (\d+)px", css)
        self.assertIsNotNone(row, "the command blocks reserve no row for the Copy button")
        # the 8px inset, a line of 12px text, 12px of padding, the border and a gap
        self.assertGreaterEqual(int(row.group(1)), 8 + 15 + 12 + 2 + 4)
        for rule in re.findall(r"\.install-code pre \{([^}]*)\}", css):
            paddings = dict(re.findall(r"(padding(?:-top|-right)?): ([^;]+);", rule))
            if not paddings:
                continue
            with self.subTest(rule=" ".join(rule.split())):
                beside = "var(--copy-room)" in paddings.get("padding", "") + paddings.get("padding-right", "")
                above = paddings.get("padding-top") == "var(--copy-row)"
                self.assertTrue(beside or above, "a command block rule reserves no room for the Copy button")

    def test_long_commands_in_faq_answers_wrap(self) -> None:
        # An inline command is one unbreakable word to the grid of the FAQ,
        # which sized its column to the longest one: at 320px the docker run
        # answer pushed the page 20px wider than the window.
        css = read("styles.css")
        rule = re.search(r"\n\.faq-item code \{([^}]*)\}", css)
        self.assertIsNotNone(rule)
        self.assertIn("overflow-wrap: anywhere", rule.group(1))


class TypographyTest(unittest.TestCase):
    def assert_absent(self, path: str, text: str, forbidden: dict[str, str]) -> None:
        for needle, reason in forbidden.items():
            index = text.find(needle)
            self.assertEqual(index, -1, f"{path}: {reason} {needle!r} in ...{around(text, index)}...")

    def test_russian_copy(self) -> None:
        for path in (*RUSSIAN_PAGES, "scripts/ru_translations.tsv", "scripts/build_ru.py", "sitemap.xml", "nav.js"):
            with self.subTest(path=path):
                text = read(path)
                self.assert_absent(path, text, FORBIDDEN_CHARACTERS)
                self.assert_absent(path, text.lower(), FORBIDDEN_RUSSIAN_WORDS)

    def test_english_copy(self) -> None:
        for path in (*build_ru.PAGES, "404.html", "README.md"):
            with self.subTest(path=path):
                self.assert_absent(path, read(path), FORBIDDEN_CHARACTERS)

    def test_spacing_around_inline_elements(self) -> None:
        for path in SITE_PAGES:
            text = read(path)
            with self.subTest(path=path):
                for pattern, problem in ((GLUED_TO_INLINE, "no space after"), (SPACE_BEFORE_PUNCTUATION, "a space before punctuation after")):
                    match = pattern.search(text)
                    self.assertIsNone(match, f"{path}: {problem} an inline element in ...{around(text, match.start()) if match else ''}...")


class SitemapTest(unittest.TestCase):
    def test_every_page_is_listed_with_its_title(self) -> None:
        ns = {
            "s": "http://www.sitemaps.org/schemas/sitemap/0.9",
            "image": "http://www.google.com/schemas/sitemap-image/1.1",
        }
        listed = {}
        for url in ET.parse(ROOT / "sitemap.xml").getroot().findall("s:url", ns):
            path = url.findtext("s:loc", namespaces=ns).removeprefix("https://coddy.dev/") + "index.html"
            listed[path] = url.findtext("image:image/image:title", namespaces=ns)
        self.assertEqual(sorted(listed), sorted(SITE_PAGES))
        for path, title in listed.items():
            with self.subTest(page=path):
                self.assertEqual(title, page_title(path))


class StructuredDataTest(unittest.TestCase):
    def test_every_page_carries_valid_json_ld(self) -> None:
        for path in SITE_PAGES:
            with self.subTest(page=path):
                self.assertTrue(json_ld(path))

    def test_faq_answers_match_the_page(self) -> None:
        faq = next(node for node in json_ld("index.html")[0]["@graph"] if node.get("@type") == "FAQPage")
        structured = {item["name"]: item["acceptedAnswer"]["text"] for item in faq["mainEntity"]}
        parser = FaqParser()
        parser.feed(read("index.html"))
        self.assertEqual(structured, parser.answers)


if __name__ == "__main__":
    unittest.main()
