#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Content-Security-Policy of the public pages: the one place that knows the policy.

GitHub Pages cannot send response headers, so every page carries its policy in a
<meta http-equiv="Content-Security-Policy"> element. Three things have to agree
on what that policy says: the page, the build step that writes it (csp_hash.py,
the last step of the post-processing chain) and the audit that checks it (rule A20
of site_audit.sh). Both of the latter import this file, so there is no second copy
of the policy, of the script hashing or of the HTML scanning to drift away.

What the policy allows (everything is same-origin unless said otherwise):
  scripts      'self' plus the sha256 of each inline script of that page. No
               'unsafe-inline' and no 'unsafe-eval': an inline event handler, a
               javascript: URL or eval() does not run.
  styles       'self' and 'unsafe-inline' (the pages use style attributes).
  images       'self'.
  connect      'self'.
  everything else not listed here falls back to default-src 'self'.
  object-src   'none', form-action 'none', base-uri 'self'.
A <meta> policy cannot carry frame-ancestors, report-to or sandbox, so it does not
protect against being framed and the pages must not claim that it does.

Hash rules, as the browser applies them: the hash is taken over the text between
<script> and </script>, UTF-8 encoded, after CR and CRLF have become LF (the HTML
input stream does that before tokenising). A NUL would be replaced by U+FFFD, so a
page that has one is refused rather than hashed wrongly.
"""
import base64
import hashlib
import re
from html.parser import HTMLParser

# ---------------------------------------------------------------------------
# The policy

SITE_HOST = 'toniliumvp.github.io'

# Directive order is the order they are written in.
BASE = (
    ('default-src', ("'self'",)),
    ('script-src', ("'self'",)),          # the page's inline script hashes follow
    ('style-src', ("'self'", "'unsafe-inline'")),
    ('img-src', ("'self'",)),
    ('font-src', ("'self'",)),
    ('connect-src', ("'self'",)),
    ('worker-src', ("'self'",)),
    ('manifest-src', ("'self'",)),
    ('object-src', ("'none'",)),
    ('base-uri', ("'self'",)),
    ('form-action', ("'none'",)),
)

# What one page needs beyond the base policy, keyed by its path from the site root.
# The modifier talks to a bridge program on the player's own machine. Its web app
# manifest names its icon as a data: URI: Chrome did not hold the icon to img-src when
# this was measured, but the rule is not the same in every browser, and the allowance
# costs nothing on a page that shows no image of its own.
PAGE_EXTRA = {
    'luna4/savedata-viewer.html': {
        'connect-src': ('http://127.0.0.1:8765',),
        'img-src': ('data:',),
    },
}

# Script types whose text the browser runs. Anything else with no src is either a
# data block (only application/ld+json is expected) or something this audit has
# never been told about, and the latter has to be looked at by a person.
JS_TYPES = ('', 'module', 'text/javascript', 'application/javascript',
            'text/ecmascript', 'application/ecmascript')
DATA_TYPES = ('application/ld+json',)

META_CSP_RE = re.compile(
    r'<meta\b[^>]*?\bhttp-equiv\s*=\s*["\']?Content-Security-Policy["\']?[^>]*>', re.I)
META_CHARSET_RE = re.compile(r'<meta\s+charset=[^>]*>', re.I)


def script_hash(text):
    """The CSP source expression for one inline script's text."""
    text = text.replace('\r\n', '\n').replace('\r', '\n')
    digest = hashlib.sha256(text.encode('utf-8')).digest()
    return "'sha256-%s'" % base64.b64encode(digest).decode('ascii')


def expected_policy(rel, hashes):
    """The policy text a page at <rel> has to carry, given its inline script hashes."""
    extra = PAGE_EXTRA.get(rel, {})
    parts = []
    for name, base in BASE:
        sources = list(base)
        if name == 'script-src':
            sources += sorted(set(hashes))
        sources += [s for s in extra.get(name, ()) if s not in sources]
        parts.append('%s %s' % (name, ' '.join(sources)))
    return '; '.join(parts)


def expected_meta(rel, hashes):
    return '<meta http-equiv="Content-Security-Policy" content="%s">' % expected_policy(rel, hashes)


def parse_policy(text):
    """directive -> list of sources, in the order written. A repeated directive is
    kept as written under a numbered key so that a duplicate shows up in the diff."""
    out = {}
    for chunk in text.split(';'):
        chunk = chunk.strip()
        if not chunk:
            continue
        name, _, rest = chunk.partition(' ')
        key = name.lower()
        n = 1
        while key in out:
            n += 1
            key = '%s#%d' % (name.lower(), n)
        out[key] = rest.split()
    return out


def policy_diff(got, want):
    """Readable differences between two policies, directive by directive."""
    g, w = parse_policy(got), parse_policy(want)
    diffs = []
    for name in list(w) + [k for k in g if k not in w]:
        gs, ws = g.get(name), w.get(name)
        if gs is None:
            diffs.append('%s missing' % name)
        elif ws is None:
            diffs.append('%s not expected' % name)
        elif sorted(gs) != sorted(ws):
            add = [s for s in gs if s not in ws]
            sub = [s for s in ws if s not in gs]
            bits = ['+' + s for s in add] + ['-' + s for s in sub]
            diffs.append('%s: %s' % (name, ' '.join(bits) if bits else 'order or repeats differ'))
    if not diffs and got.strip() != want.strip():
        diffs.append('same sources, written differently')
    return diffs


# ---------------------------------------------------------------------------
# Scanning a page

class _Scan(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=False)
        self.tags = []        # (name, attrs, line) of every start tag, in order
        self.scripts = []     # every <script> element: line, attrs, text
        self._cur = None
        self.opened = 0

    def handle_starttag(self, tag, attrs):
        d = {}
        for k, v in attrs:
            d.setdefault(k.lower(), v if v is not None else '')
        line = self.getpos()[0]
        self.tags.append((tag, d, line))
        if tag == 'script':
            self.opened += 1
            self._cur = {'line': line, 'attrs': d, 'text': ''}

    def handle_data(self, data):
        if self._cur is not None:
            self._cur['text'] += data

    def handle_endtag(self, tag):
        if tag == 'script' and self._cur is not None:
            self.scripts.append(self._cur)
            self._cur = None


class Page:
    """What the audit and the build step need to know about one page."""
    def __init__(self, text):
        if '\x00' in text:
            raise ValueError('contains a NUL character (a browser would read it as U+FFFD)')
        text = text.replace('\r\n', '\n').replace('\r', '\n')
        s = _Scan()
        try:
            s.feed(text)
            s.close()
        except Exception as e:  # html.parser has no single error type
            raise ValueError('cannot parse the HTML (%s: %s)' % (type(e).__name__, e))
        # The parser stops a script at </script> and a browser also stops it at
        # "</script " or "</script/", and a "<script/>" is a start tag to the parser
        # but not to a browser. Where a plain scan and the parser disagree about how
        # many scripts there are, the hash of one of them could be wrong: refuse.
        n_open = len(re.findall(r'<script(?=[\s/>])', text, re.I))
        n_close = len(re.findall(r'</script(?=[\s/>])', text, re.I))
        if not (n_open == s.opened == len(s.scripts) == n_close):
            raise ValueError('the parser and a plain scan disagree on the script elements '
                             '(%d opening, %d parsed, %d closing)' % (n_open, len(s.scripts), n_close))
        self.text = text
        self.tags = s.tags
        self.scripts = s.scripts

    # -- scripts
    def inline_scripts(self):
        """(line, text) for every inline script the browser would run."""
        out = []
        for sc in self.scripts:
            if 'src' in sc['attrs']:
                continue
            kind = sc['attrs'].get('type', '').strip().lower()
            if kind in DATA_TYPES:
                continue
            out.append((sc['line'], sc['text']))
        return out

    def unknown_script_types(self):
        out = []
        for sc in self.scripts:
            if 'src' in sc['attrs']:
                continue
            kind = sc['attrs'].get('type', '').strip().lower()
            if kind not in JS_TYPES and kind not in DATA_TYPES:
                out.append((sc['line'], kind))
        return out

    def hashes(self):
        return sorted({script_hash(t) for _, t in self.inline_scripts()})

    # -- the policy element
    def csp_metas(self):
        """(position in the start tag sequence, line, content) of each CSP meta."""
        out = []
        for i, (tag, a, line) in enumerate(self.tags):
            if tag == 'meta' and a.get('http-equiv', '').strip().lower() == 'content-security-policy':
                out.append((i, line, a.get('content', '')))
        return out

    def charset_position(self):
        pos = [i for i, (tag, a, _) in enumerate(self.tags) if tag == 'meta' and 'charset' in a]
        return pos

    # -- things the policy would silently switch off
    def handlers(self):
        out = []
        for tag, a, line in self.tags:
            for k in a:
                if re.fullmatch(r'on[a-z]+', k):
                    out.append((line, '<%s %s=...>' % (tag, k)))
        return out

    def javascript_urls(self):
        out = []
        for tag, a, line in self.tags:
            for k in ('href', 'src', 'action', 'formaction', 'data', 'poster', 'xlink:href'):
                v = a.get(k)
                if v is None:
                    continue
                norm = re.sub(r'[\t\n\r]', '', v).lstrip(''.join(chr(c) for c in range(0x21))).lower()
                if norm.startswith('javascript:'):
                    out.append((line, '<%s %s="javascript:...">' % (tag, k)))
        return out

    def outside_resources(self):
        """Sub-resources that are not same-origin (or are data: URIs): 'self' blocks them."""
        out = []
        for tag, a, line in self.tags:
            ref = None
            if tag == 'link':
                rel = a.get('rel', '').lower().split()
                if any(r in rel for r in ('stylesheet', 'icon', 'manifest', 'preload', 'modulepreload', 'prefetch')):
                    ref = a.get('href')
            elif tag in ('script', 'img', 'iframe', 'source', 'video', 'audio', 'embed', 'track', 'frame'):
                ref = a.get('src')
            elif tag == 'object':
                ref = a.get('data')
            elif tag == 'input' and a.get('type', '').lower() == 'image':
                ref = a.get('src')
            if ref is None:
                continue
            v = re.sub(r'[\t\n\r]', '', ref).strip()
            low = v.lower()
            if low.startswith('data:'):
                out.append((line, '<%s> loads a data: URI' % tag, 'data'))
                continue
            m = re.match(r'(?:(?:https?:)?//)([^/?#:]*)', v, re.I)
            if m and m.group(1).lower() != SITE_HOST:
                out.append((line, '<%s> loads %s from another origin' % (tag, m.group(1) or v[:40]), 'external'))
            elif re.match(r'[a-z][a-z0-9+.-]*:', low) and not low.startswith(('http:', 'https:')):
                out.append((line, '<%s> loads a %s: URL' % (tag, low.split(':')[0]), 'scheme'))
        return out


# ---------------------------------------------------------------------------
# Checking one page (rule A20)

def check_page(rel, text):
    """Problems found on one page; an empty list means the page is correct."""
    page = Page(text)
    problems = []
    hashes = page.hashes()
    metas = page.csp_metas()

    if not metas:
        problems.append('no Content-Security-Policy meta element')
        got = None
    else:
        if len(metas) > 1:
            problems.append('%d Content-Security-Policy meta elements (line %s), exactly one is allowed'
                            % (len(metas), ', '.join(str(m[1]) for m in metas)))
        idx, line, got = metas[0]
        cs = page.charset_position()
        if len(cs) != 1:
            problems.append('%d <meta charset> elements, the policy has no fixed place to follow' % len(cs))
        elif idx != cs[0] + 1:
            problems.append('the policy (line %d) is not the element right after <meta charset>' % line)

    for ln, kind in page.unknown_script_types():
        problems.append('inline script of unknown type "%s" at line %d: decide whether it needs a hash' % (kind, ln))

    if got is not None:
        listed = set(parse_policy(got).get('script-src', []))
        for ln, t in page.inline_scripts():
            h = script_hash(t)
            if h not in listed:
                problems.append('inline script at line %d is not in script-src (%s)' % (ln, h[:22] + "...'"))
        want = expected_policy(rel, hashes)
        if got.strip() != want:
            diffs = policy_diff(got, want)
            problems.append('the policy differs from the expected one: ' + '; '.join(diffs[:4]))

    for ln, what in page.handlers():
        problems.append('%s at line %d does not run under the policy' % (what, ln))
    for ln, what in page.javascript_urls():
        problems.append('%s at line %d does not run under the policy' % (what, ln))
    extra = PAGE_EXTRA.get(rel, {})
    for ln, what, kind in page.outside_resources():
        if kind == 'data' and 'data:' in extra.get('img-src', ()):
            continue
        problems.append('%s at line %d is blocked by the policy' % (what, ln))
    return problems


def has_csp_meta(text):
    """Used for the shell's cross-check: does the page carry a policy element at all."""
    return bool(Page(text).csp_metas())


def audit(files, skip=lambda f: False):
    """Check every .html file of the list, paths relative to the working directory.

    Returns (problems, scanned, unreadable, without_policy): problems is a list of
    (file, message); the last two are counts. A file that cannot be read, decoded
    or parsed is a problem and is counted as unreadable. skip is for the self-test's
    bait pages: they are still counted as scanned.
    """
    import os
    problems = []
    scanned = unreadable = without = 0
    for f in files:
        f = f.strip()
        if not f.endswith('.html'):
            continue
        scanned += 1
        if skip(f):
            continue
        if not os.path.isfile(f):
            problems.append((f, 'UNREADABLE: not a file'))
            unreadable += 1
            continue
        try:
            with open(f, 'rb') as fh:
                text = fh.read().decode('utf-8')
            probs = check_page(f, text)
        except (OSError, UnicodeDecodeError, ValueError) as e:
            problems.append((f, 'UNREADABLE: %s' % e))
            unreadable += 1
            continue
        if any(p.startswith('no Content-Security-Policy') for p in probs):
            without += 1
        for p in probs:
            problems.append((f, p))
    # A page-specific entry whose page is gone while the pages beside it are still listed
    # means the page was renamed or removed: it would silently lose what it needs.
    listed = {f.strip() for f in files}
    for key in PAGE_EXTRA:
        folder = key.rsplit('/', 1)[0] + '/' if '/' in key else ''
        beside = [f for f in listed if f.endswith('.html') and f.startswith(folder)]
        if beside and key not in listed:
            problems.append((key, 'a page-specific policy entry names a page that is not in the list '
                                  'although the pages beside it are'))
    return problems, scanned, unreadable, without


# ---------------------------------------------------------------------------
# Writing the policy into a page (used by the build step)

def apply_page(rel, text):
    """The page with its policy element written, or the same text when it is right.

    The element goes on the line right after <meta charset>, before every stylesheet
    and script, which is where a browser starts to enforce it. Any policy element
    the page had is replaced, wherever it was. Nothing else in the page changes.
    """
    if '\r' in text:
        raise ValueError('contains a CR: normalise the line endings first, a CSP edit must not touch them')
    page = Page(text)
    charset = list(META_CHARSET_RE.finditer(text))
    if len(charset) != 1:
        raise ValueError('expected exactly one <meta charset>, found %d' % len(charset))
    old = list(META_CSP_RE.finditer(text))
    if len(old) != len(page.csp_metas()):
        raise ValueError('the parser and a plain scan disagree on the policy elements (%d vs %d)'
                         % (len(page.csp_metas()), len(old)))
    meta = expected_meta(rel, page.hashes())
    # drop the old elements, with the line break in front of each one
    out, pos = [], 0
    for m in old:
        start = m.start()
        if start > 0 and text[start - 1] == '\n':
            start -= 1
        out.append(text[pos:start])
        pos = m.end()
    out.append(text[pos:])
    stripped = ''.join(out)
    c = META_CHARSET_RE.search(stripped)
    result = stripped[:c.end()] + '\n' + meta + stripped[c.end():]
    # what was written has to read back as exactly the policy that was meant
    back = Page(result)
    metas = back.csp_metas()
    cs = back.charset_position()
    if (len(metas) != 1 or len(cs) != 1 or metas[0][0] != cs[0] + 1
            or metas[0][2] != expected_policy(rel, back.hashes())):
        raise ValueError('the page did not read back with the policy it was given')
    return result
