"""Human-edited English-to-Russian text used by build_ru.py."""

from pathlib import Path


TRANSLATIONS = {}
for line in Path(__file__).with_name("ru_translations.tsv").read_text(encoding="utf-8").splitlines():
    if not line or line.startswith("#"):
        continue
    source, translation = line.split("\t", 1)
    if source in TRANSLATIONS:
        raise ValueError(f"Duplicate translation: {source}")
    TRANSLATIONS[source] = translation
