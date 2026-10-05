#!/usr/bin/env python3
"""Which characters do the pages that load fonts-wuxia.css need to draw?

One definition, used twice: by the build step that cuts the Noto Serif TC web font down to
the characters the pages use, and by the audit rule that checks every character a page
needs is still in the shipped font. A second copy of the extraction rules anywhere else
would let the two disagree, and a character that one side counts and the other does not
is exactly the character that silently falls back to a system font.

What counts as "needed by a page" (a superset on purpose: a font that carries a character
nobody draws costs a few bytes, a font that lacks one costs a fallback font on screen):

  * all text in the page body, <pre> included, with HTML entities decoded and every
    character taken as a code point (so characters outside the BMP count too);
  * the text attributes a browser can draw or show: placeholder, value, alt, title,
    aria-label and a few more;
  * string literals in inline scripts (and in local external scripts), escapes decoded;
    comments and regular expressions are not text and are skipped;
  * string literals in the CSS that sets generated content (content, quotes, list-style,
    the counter-style strings and custom properties), from every stylesheet the page links
    and from inline <style> blocks;
  * U+0020 to U+007E, always.

Never counted: <head>, JSON-LD and other data blocks that nothing draws, comments.

Standard library only: the audit runs it on a machine with nothing else installed.
"""
import html.parser
import os
import re
import sys

MARKER = 'fonts-wuxia.css'

# Attributes whose value a browser draws (placeholder, value, alt of a broken image) or
# shows as a tooltip (title). The aria-* ones are read out, not drawn, and are kept so
# that adding one cannot make a page need a character the font does not have.
TEXT_ATTRS = ('placeholder', 'value', 'alt', 'title', 'aria-label', 'label',
              'aria-placeholder', 'aria-roledescription', 'aria-valuetext')

# CSS properties that can put text on screen without it being in the HTML.
CSS_TEXT_PROPS = ('content', 'quotes', 'list-style', 'list-style-type', 'symbols',
                  'prefix', 'suffix', 'pad', 'negative', 'additive-symbols')

ALWAYS = [chr(c) for c in range(0x20, 0x7f)]
ALWAYS_LABEL = '(always included: U+0020 to U+007E)'


# ---------------------------------------------------------------------------
# unicode-range text
# ---------------------------------------------------------------------------

def parse_unicode_ranges(text):
    """The code points a unicode-range value (or a coverage listing) names."""
    out = set()
    text = re.sub(r'/\*.*?\*/', ' ', text, flags=re.S)   # a CSS comment between the entries
    for tok in re.split(r'[,\s]+', text.strip()):
        if not tok:
            continue
        m = re.fullmatch(r'[Uu]\+([0-9A-Fa-f?]{1,6})(?:-([0-9A-Fa-f]{1,6}))?', tok)
        if not m:
            raise ValueError('not a unicode-range token: %r' % tok)
        a, b = m.group(1), m.group(2)
        if '?' in a:
            lo, hi = int(a.replace('?', '0'), 16), int(a.replace('?', 'f'), 16)
        else:
            lo = int(a, 16)
            hi = int(b, 16) if b else lo
        if hi < lo:
            raise ValueError('reversed range: %r' % tok)
        out.update(range(lo, hi + 1))
    return out


def format_unicode_ranges(cps):
    """The shortest 'U+a, U+b-c' form of a set of code points (lower case, like Google Fonts)."""
    cps = sorted(set(cps))
    parts = []
    i = 0
    while i < len(cps):
        j = i
        while j + 1 < len(cps) and cps[j + 1] == cps[j] + 1:
            j += 1
        if j == i:
            parts.append('U+%04x' % cps[i])
        else:
            parts.append('U+%04x-%04x' % (cps[i], cps[j]))
        i = j + 1
    return ', '.join(parts)


def serif_ranges(css_text):
    """The union of the unicode-range of every Noto Serif TC @font-face in a stylesheet."""
    cps = set()
    faces = 0
    for block in re.findall(r'@font-face\s*\{(.*?)\}', css_text, re.S):
        fam = re.search(r'font-family\s*:\s*[\'"]?([^;\'"]+)', block)
        if not fam or fam.group(1).strip() != 'Noto Serif TC':
            continue
        rng = re.search(r'unicode-range\s*:\s*([^;]+);', block, re.S)
        if not rng:
            raise ValueError('a Noto Serif TC @font-face without unicode-range')
        cps |= parse_unicode_ranges(rng.group(1))
        faces += 1
    return cps, faces


def font_urls(css_text):
    """Every url(...) a stylesheet's @font-face rules point at, in order."""
    urls = []
    for block in re.findall(r'@font-face\s*\{(.*?)\}', css_text, re.S):
        urls += re.findall(r'url\(\s*[\'"]?([^)\'"]+?)[\'"]?\s*\)', block)
    return urls


# ---------------------------------------------------------------------------
# CSS and JS string literals
# ---------------------------------------------------------------------------

def _css_unescape(s, i):
    """s[i] is the character after a backslash. Returns (text, next index)."""
    c = s[i] if i < len(s) else ''
    if c == '':
        return '', i
    if c == '\n':
        return '', i + 1
    m = re.match(r'[0-9A-Fa-f]{1,6}', s[i:])
    if m:
        v = int(m.group(0), 16)
        j = i + len(m.group(0))
        if j < len(s) and s[j] in ' \t\n':
            j += 1
        if v == 0 or v > 0x10FFFF or 0xD800 <= v <= 0xDFFF:
            v = 0xFFFD
        return chr(v), j
    return c, i + 1


def css_strings(css_text):
    """Decoded string literals of the declarations in CSS_TEXT_PROPS, comments left out."""
    s = css_text
    n = len(s)
    # Remove comments, string aware (a "/*" inside a string is not a comment).
    buf = []
    i = 0
    while i < n:
        c = s[i]
        if c == '/' and s[i + 1:i + 2] == '*':
            j = s.find('*/', i + 2)
            i = n if j < 0 else j + 2
            buf.append(' ')
        elif c in '"\'':
            j = i + 1
            while j < n and s[j] != c:
                j += 2 if s[j] == '\\' else 1
            buf.append(s[i:j + 1])
            i = j + 1
        else:
            buf.append(c)
            i += 1
    s = ''.join(buf)
    n = len(s)
    out = []
    # Custom properties too: a string kept in a --variable can reach the page through var().
    prop_re = re.compile(r'(?<![\w-])(--[\w-]+|' + '|'.join(re.escape(p) for p in CSS_TEXT_PROPS) + r')\s*:')
    for m in prop_re.finditer(s):
        i = m.end()
        while i < n and s[i] not in ';}':
            c = s[i]
            if c in '"\'':
                q = c
                i += 1
                chunk = []
                while i < n and s[i] != q:
                    if s[i] == '\\':
                        t, i = _css_unescape(s, i + 1)
                        chunk.append(t)
                    else:
                        chunk.append(s[i])
                        i += 1
                out.append(''.join(chunk))
                i += 1
            else:
                i += 1
    return '\n'.join(out)


_JS_REGEX_AFTER_WORDS = {'return', 'typeof', 'instanceof', 'in', 'of', 'new', 'delete', 'void',
                         'throw', 'case', 'do', 'else', 'yield', 'await'}


def js_strings(src):
    """Decoded contents of the string and template literals in a piece of JavaScript.

    Comments and regular expression literals are skipped: neither is text a page draws.
    Template literals are followed into their ${...} parts.
    """
    s = src
    n = len(s)
    out = []
    stack = []      # brace depth at which each open ${ started
    depth = 0
    prev = ''       # last significant token: a single character, or an identifier word
    i = 0

    def escape(i):
        """s[i] is the character after a backslash: (text, next index)."""
        c = s[i] if i < n else ''
        if c == '':
            return '', i
        simple = {'n': '\n', 't': '\t', 'r': '\r', 'b': '\b', 'f': '\f', 'v': '\v', '0': '\0'}
        if c == 'x':
            m = re.match(r'[0-9A-Fa-f]{2}', s[i + 1:])
            if m:
                return chr(int(m.group(0), 16)), i + 3
        if c == 'u':
            m = re.match(r'\{([0-9A-Fa-f]{1,6})\}', s[i + 1:])
            if m:
                v = int(m.group(1), 16)
                return (chr(v) if v <= 0x10FFFF else ''), i + 1 + len(m.group(0))
            m = re.match(r'[0-9A-Fa-f]{4}', s[i + 1:])
            if m:
                return chr(int(m.group(0), 16)), i + 5
        if c in '\r\n':
            j = i + 1
            if c == '\r' and s[j:j + 1] == '\n':
                j += 1
            return '', j
        if c in '1234567':
            m = re.match(r'[0-7]{1,3}', s[i:])
            return chr(int(m.group(0), 8)), i + len(m.group(0))
        return simple.get(c, c), i + 1

    def plain(i, quote):
        """Read a '...' or "..." literal; i is after the opening quote."""
        buf = []
        while i < n and s[i] != quote and s[i] != '\n':
            if s[i] == '\\':
                t, i = escape(i + 1)
                buf.append(t)
            else:
                buf.append(s[i])
                i += 1
        out.append(''.join(buf))
        return i + 1

    def template(i):
        """Read template text from i. Returns the index to continue the code at."""
        buf = []
        while i < n:
            c = s[i]
            if c == '`':
                out.append(''.join(buf))
                return i + 1
            if c == '\\':
                t, i = escape(i + 1)
                buf.append(t)
            elif c == '$' and s[i + 1:i + 2] == '{':
                out.append(''.join(buf))
                stack.append(depth)
                return i + 2
            else:
                buf.append(c)
                i += 1
        out.append(''.join(buf))
        return i

    while i < n:
        c = s[i]
        if c in ' \t\r\n':
            i += 1
        elif c == '/' and s[i + 1:i + 2] == '/':
            j = s.find('\n', i)
            i = n if j < 0 else j
        elif c == '/' and s[i + 1:i + 2] == '*':
            j = s.find('*/', i + 2)
            i = n if j < 0 else j + 2
        elif c in '"\'':
            i = plain(i + 1, c)
            prev = '"'
        elif c == '`':
            i = template(i + 1)
            prev = '"'
        elif c == '/':
            if prev == '' or (len(prev) == 1 and prev in '(,=:[!&|?{};+-*%<>~^') or prev in _JS_REGEX_AFTER_WORDS:
                i += 1
                in_class = False
                while i < n and s[i] != '\n':
                    if s[i] == '\\':
                        i += 2
                        continue
                    if s[i] == '[':
                        in_class = True
                    elif s[i] == ']':
                        in_class = False
                    elif s[i] == '/' and not in_class:
                        break
                    i += 1
                i += 1
                while i < n and s[i].isalpha():
                    i += 1
                prev = '"'
            else:
                i += 1
                prev = '/'
        elif c.isalpha() or c in '_$':
            m = re.compile(r'[\w$]+').match(s, i)
            prev = m.group(0)
            i = m.end()
        elif c.isdigit():
            m = re.compile(r'[\w.]+').match(s, i)
            prev = '0'
            i = m.end()
        elif c == '{':
            depth += 1
            prev = c
            i += 1
        elif c == '}':
            if stack and stack[-1] == depth:
                stack.pop()
                i = template(i + 1)
                prev = '"'
            else:
                depth -= 1
                prev = c
                i += 1
        else:
            prev = c
            i += 1
    return out


# ---------------------------------------------------------------------------
# HTML
# ---------------------------------------------------------------------------

class _Page(html.parser.HTMLParser):
    """Collects what a page draws. self.found maps a character to the kinds it came from."""

    JS_TYPES = ('', 'text/javascript', 'application/javascript', 'module', 'text/ecmascript',
                'application/ecmascript')

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.found = {}
        self.stylesheets = []     # hrefs of <link rel=stylesheet>
        self.scripts = []         # src of external scripts
        self.in_head = False
        self.pre = 0
        self.raw = None           # ('style'|'script', type) while inside one of them
        self.raw_buf = []

    def _add(self, text, kind):
        for ch in text:
            o = ord(ch)
            if o < 0x20 or o == 0x7f or 0xD800 <= o <= 0xDFFF:
                continue
            self.found.setdefault(ch, set()).add(kind)

    def handle_starttag(self, tag, attrs):
        a = dict((k, v if v is not None else '') for k, v in attrs)
        if tag == 'head':
            self.in_head = True
            return
        if tag == 'body':
            self.in_head = False
        if tag == 'link' and 'stylesheet' in a.get('rel', '').lower().split():
            if a.get('href'):
                self.stylesheets.append(a['href'])
            return
        if tag == 'style':
            self.raw = ('style', '')
            self.raw_buf = []
            return
        if tag == 'script':
            if a.get('src'):
                self.scripts.append(a['src'])
            self.raw = ('script', a.get('type', '').strip().lower())
            self.raw_buf = []
            return
        if tag == 'pre':
            self.pre += 1
        if self.in_head:
            return
        for name in TEXT_ATTRS:
            if name in a:
                self._add(a[name], 'attr')

    def handle_endtag(self, tag):
        if tag == 'head':
            self.in_head = False
        elif tag == 'pre' and self.pre:
            self.pre -= 1
        elif tag in ('style', 'script') and self.raw and self.raw[0] == tag:
            kind, typ = self.raw
            body = ''.join(self.raw_buf)
            self.raw = None
            self.raw_buf = []
            if kind == 'style':
                self._add(css_strings(body), 'css')
            elif typ in self.JS_TYPES:
                for lit in js_strings(body):
                    self._add(lit, 'script')
            elif 'ld+json' in typ:
                pass
            else:
                self._add(body, 'script')   # some other data block: count all of it, to be safe

    def handle_data(self, data):
        if self.raw:
            self.raw_buf.append(data)
        elif not self.in_head:
            self._add(data, 'pre' if self.pre else 'text')

    def close(self):
        super().close()
        # An unterminated <script> or <style> still counts: nothing hides behind a missing end tag.
        # (The parser keeps the unread rest of such a block back, so it is taken from there.)
        if self.raw:
            self.raw_buf.append(self.rawdata)
            self.rawdata = ''
            self.handle_endtag(self.raw[0])


def page_chars(text):
    """(chars, stylesheets, scripts) for one page's HTML text."""
    p = _Page()
    p.feed(text)
    p.close()
    return p.found, p.stylesheets, p.scripts


def _resolve(page_rel, href, root):
    """The file a local href points at, relative to root, or None for an external one."""
    href = href.split('#')[0].split('?')[0].strip()
    if not href or re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', href) or href.startswith('//'):
        return None
    if href.startswith('/LunaticDawn/'):
        rel = href[len('/LunaticDawn/'):]
    elif href.startswith('/'):
        rel = href.lstrip('/')
    else:
        rel = os.path.normpath(os.path.join(os.path.dirname(page_rel), href))
    return rel.replace(os.sep, '/')


def read_text(root, rel):
    with open(os.path.join(root, rel), encoding='utf-8') as fh:   # strict: a bad byte must stop the run
        return fh.read()


def wuxia_pages(files, root):
    """The .html files among FILES that link fonts-wuxia.css, in sorted order."""
    pages = []
    for f in files:
        f = f.strip()
        if f.endswith('.html') and MARKER in read_text(root, f):
            pages.append(f)
    return sorted(set(pages))


def extract_detailed(files, root='.'):
    """Everything the extraction found.

    Returns a dict: pages (list), chars {char: sorted files}, kinds {char: sorted kinds},
    css (stylesheets read), scripts (external scripts read).
    """
    pages = wuxia_pages(files, root)
    where = {}
    kinds = {}
    css_done = {}
    js_done = {}

    def note(ch, src, kind_set):
        where.setdefault(ch, set()).add(src)
        kinds.setdefault(ch, set()).update(kind_set)

    for p in pages:
        found, sheets, scripts = page_chars(read_text(root, p))
        for ch, ks in found.items():
            note(ch, p, ks)
        for href in sheets:
            rel = _resolve(p, href, root)
            if rel is None or rel in css_done:
                continue
            css_done[rel] = css_strings(read_text(root, rel))
        for src in scripts:
            rel = _resolve(p, src, root)
            if rel is None or rel in js_done:
                continue
            js_done[rel] = ''.join(js_strings(read_text(root, rel)))
    for rel, text in list(css_done.items()) + list(js_done.items()):
        for ch in text:
            o = ord(ch)
            if o < 0x20 or o == 0x7f or 0xD800 <= o <= 0xDFFF:
                continue
            note(ch, rel, {'css' if rel.endswith('.css') else 'script'})
    for ch in ALWAYS:
        note(ch, ALWAYS_LABEL, {'always'})
    return {
        'pages': pages,
        'chars': {ch: sorted(v) for ch, v in where.items()},
        'kinds': {ch: sorted(v) for ch, v in kinds.items()},
        'css': sorted(css_done),
        'scripts': sorted(js_done),
    }


def extract(files, root='.'):
    """{character: [files it appears in]} for the pages in FILES that link fonts-wuxia.css."""
    return extract_detailed(files, root)['chars']


# ---------------------------------------------------------------------------
# audit
# ---------------------------------------------------------------------------

def audit(files, root, coverage_path, css_rel='assets/css/fonts-wuxia.css'):
    """Check that the shipped font still has every character the pages need.

    A character is a problem when the full Noto Serif TC could draw it (it is in the coverage
    listing the build step wrote) but no @font-face of the shipped stylesheet carries it. A
    character the full font never had falls back to a system font before and after, so it is
    not the shipped font's doing and is not reported.
    Returns (problems, pages_scanned). Raises when the rule cannot do its job.
    """
    css = read_text(root, css_rel)
    shipped, faces = serif_ranges(css)
    if faces == 0 or not shipped:
        raise RuntimeError('%s has no Noto Serif TC @font-face with a unicode-range' % css_rel)
    with open(coverage_path, encoding='utf-8') as fh:
        cov_text = ''.join(l for l in fh if not l.lstrip().startswith('#'))
    coverage = parse_unicode_ranges(cov_text)
    if not coverage:
        raise RuntimeError('the font coverage listing %s is empty' % coverage_path)
    if not shipped <= coverage:
        extra = sorted(shipped - coverage)[:5]
        raise RuntimeError('the shipped font claims characters the full font does not have (%s): '
                           'the coverage listing is out of date' % ' '.join('U+%04X' % c for c in extra))
    res = extract_detailed(files, root)
    if not res['pages']:
        raise RuntimeError('no page links %s: wrong directory?' % MARKER)
    problems = []
    for ch, srcs in sorted(res['chars'].items()):
        cp = ord(ch)
        if cp in coverage and cp not in shipped:
            problems.append((cp, ch, srcs))
    # Every file the stylesheet points at has to be there.
    for url in font_urls(css):
        rel = _resolve(css_rel, url, root)
        if rel is None:
            continue
        if not os.path.isfile(os.path.join(root, rel)):
            problems.append((None, rel, [css_rel]))
    return problems, len(res['pages'])


def _main(argv):
    import subprocess
    root = '.'
    args = argv[1:]
    if args[:1] == ['--root'] and len(args) >= 2:
        root, args = args[1], args[2:]
    if args:
        files = args
    else:
        files = subprocess.run(['git', '-C', root, '-c', 'core.quotePath=false', 'ls-files'], check=True,
                               capture_output=True, text=True).stdout.split('\n')
    res = extract_detailed([f for f in files if f], root)
    print('pages: %d  characters: %d  (non-ASCII: %d)' % (
        len(res['pages']), len(res['chars']), sum(1 for c in res['chars'] if ord(c) > 0x7f)))
    kinds = {}
    for ch, ks in res['kinds'].items():
        if ord(ch) > 0x7f:
            kinds[tuple(ks)] = kinds.get(tuple(ks), 0) + 1
    for k, v in sorted(kinds.items(), key=lambda kv: -kv[1]):
        print('  %-24s %d' % ('+'.join(k), v))
    print('stylesheets read: %s' % ', '.join(res['css']))
    return 0


if __name__ == '__main__':
    sys.exit(_main(sys.argv))
