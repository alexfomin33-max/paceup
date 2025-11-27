from pathlib import ath
import re

patterns = [
    (re.compile(r"(['\"])((?:\.\./)+)widgets/([^'\"]+)(['\"])"), "package:paceup/core/widgets/"),
    (re.compile(r"(['\"])((?:\.\./)+)theme/([^'\"]+)(['\"])"), "package:paceup/core/theme/"),
    (re.compile(r"(['\"])((?:\.\./)+)service/([^'\"]+)(['\"])"), "package:paceup/core/services/"),
    (re.compile(r"(['\"])((?:\.\./)+)database/([^'\"]+)(['\"])"), "package:paceup/core/database/"),
    (re.compile(r"(['\"])((?:\.\./)+)utils/([^'\"]+)(['\"])"), "package:paceup/core/utils/"),
]

updated = 0
for path in ath('lib').rglob('*.dart'):
    text = path.read_text(encoding='utf-8')
    new_text = text
    for pattern, replacement in patterns:
        def repl(match):
            return f"{match.group(1)}{replacement}{match.group(3)}{match.group(4)}"
        new_text = pattern.sub(repl, new_text)
    if new_text != text:
        path.write_text(new_text, encoding='utf-8')
        updated += 1

print(f"normalized relative imports: {updated}")
