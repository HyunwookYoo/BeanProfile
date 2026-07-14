#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""BeanProfile 문서용 마크다운 -> 테마 HTML 변환기.

앱과 동일한 "커핑 랩" 디자인(웜 오트/에스프레소/크레마, 다크 모노 코드블록,
라이트·다크 자동)으로 렌더링한다. 외부 의존성 없음(파이썬 표준 라이브러리만).

사용법:
    python scripts/md2html.py docs/plans/roadmap.md [다른.md ...]
    python scripts/md2html.py --all      # docs/ 아래 모든 .md 변환

각 <경로>.md 는 같은 위치에 <경로>.html 로 출력된다.
Artifact로 발행하려면 생성된 .html 을 발행하면 된다(동일 경로 재발행 시 URL 유지).

지원 문법: #~###### 제목 · **굵게** · `인라인 코드` · ```펜스 코드``` ·
표 · > 인용 · --- 구분선 · 목록/체크박스(- [ ]) · [링크](url).
"""
import html
import re
import sys
import pathlib

sys.stdout.reconfigure(encoding="utf-8")

ROOT = pathlib.Path(__file__).resolve().parent.parent  # 프로젝트 루트

CSS = r'''
*{box-sizing:border-box}
:root{
  --bg:#EFEAE0;--fg:#2B2019;--muted:#7A6F62;--line:#DED6C7;--accent:#A66A24;--accent-ink:#8A5A18;
  --surface:#F7F3EC;--th:#E7DFD1;--code-bg:#221A11;--code-fg:#ECE3D3;--ic-bg:#E7DFD0;--ic-fg:#7A5216;
  --font-sans:"Pretendard","Apple SD Gothic Neo","Malgun Gothic",system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
  --font-mono:ui-monospace,"SF Mono","JetBrains Mono","Cascadia Code",Consolas,"Malgun Gothic",monospace;
}
@media (prefers-color-scheme:dark){:root{
  --bg:#1B1510;--fg:#EDE5D8;--muted:#9C9081;--line:#332A21;--accent:#D89A46;--accent-ink:#E4B677;
  --surface:#241D16;--th:#2B231B;--code-bg:#100D08;--code-fg:#ECE3D3;--ic-bg:#2B231B;--ic-fg:#E4B677;
}}
:root[data-theme="light"]{
  --bg:#EFEAE0;--fg:#2B2019;--muted:#7A6F62;--line:#DED6C7;--accent:#A66A24;--accent-ink:#8A5A18;
  --surface:#F7F3EC;--th:#E7DFD1;--code-bg:#221A11;--code-fg:#ECE3D3;--ic-bg:#E7DFD0;--ic-fg:#7A5216;
}
:root[data-theme="dark"]{
  --bg:#1B1510;--fg:#EDE5D8;--muted:#9C9081;--line:#332A21;--accent:#D89A46;--accent-ink:#E4B677;
  --surface:#241D16;--th:#2B231B;--code-bg:#100D08;--code-fg:#ECE3D3;--ic-bg:#2B231B;--ic-fg:#E4B677;
}
body{margin:0;background:var(--bg);color:var(--fg);font-family:var(--font-sans);line-height:1.7;-webkit-font-smoothing:antialiased}
@media (prefers-reduced-motion:reduce){*{transition:none!important;animation:none!important}}
.doc{max-width:880px;margin:0 auto;padding:44px 24px 96px}
.crumb{font-family:var(--font-mono);font-size:12px;letter-spacing:.12em;text-transform:uppercase;color:var(--accent);margin-bottom:16px}
h1{font-size:clamp(26px,4vw,38px);font-weight:800;letter-spacing:-.025em;line-height:1.2;margin:.1em 0 .5em;text-wrap:balance}
h2{font-size:22px;font-weight:700;margin:2em 0 .7em;padding-bottom:.3em;border-bottom:1px solid var(--line);letter-spacing:-.01em;text-wrap:balance}
h3{font-size:16.5px;font-weight:700;color:var(--accent-ink);margin:1.7em 0 .5em}
h4{font-size:14px;font-weight:700;margin:1.3em 0 .4em}
p{margin:.7em 0}
a{color:var(--accent);text-decoration:underline;text-underline-offset:2px;text-decoration-thickness:1px}
strong{font-weight:700;color:var(--fg)}
hr{border:none;border-top:1px solid var(--line);margin:2em 0}
code.ic{font-family:var(--font-mono);font-size:.85em;background:var(--ic-bg);color:var(--ic-fg);padding:1.5px 6px;border-radius:6px}
pre.code{position:relative;background:var(--code-bg);color:var(--code-fg);border-radius:12px;padding:16px 18px;margin:1em 0;overflow-x:auto;border:1px solid rgba(0,0,0,.28)}
pre.code code{font-family:var(--font-mono);font-size:12.75px;line-height:1.6;white-space:pre;color:inherit;background:none;padding:0}
pre.code[data-lang]::before{content:attr(data-lang);position:absolute;top:9px;right:13px;font-family:var(--font-mono);font-size:10px;letter-spacing:.14em;text-transform:uppercase;color:rgba(236,227,211,.42)}
.tablewrap{overflow-x:auto;margin:1.1em 0}
table{border-collapse:collapse;width:100%;font-size:13.75px}
th,td{border:1px solid var(--line);padding:8px 11px;text-align:left;vertical-align:top}
th{background:var(--th);font-weight:700}
tbody tr:nth-child(even){background:var(--surface)}
blockquote{margin:1.1em 0;padding:11px 16px;border-left:3px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;color:var(--muted)}
blockquote strong{color:var(--fg)}
ul,ol{margin:.7em 0;padding-left:1.4em}
li{margin:.32em 0}
ul.tasklist{list-style:none;padding-left:.15em}
ul.tasklist li.task{position:relative;padding-left:30px;margin:.5em 0}
ul.tasklist li.task::before{content:"";position:absolute;left:0;top:.18em;width:17px;height:17px;border:2px solid var(--accent);border-radius:5px;background:transparent}
ul.tasklist li.task.done::before{content:"\2713";background:var(--accent);color:#fff;font-size:12px;font-weight:800;text-align:center;line-height:15px}
'''


def inline(s):
    s = html.escape(s, quote=False)
    codes = []

    def stash(m):
        codes.append(m.group(1))
        return "\x00%d\x00" % (len(codes) - 1)

    s = re.sub(r'`([^`]+)`', stash, s)
    s = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', s)
    s = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', s)
    s = re.sub(r'\x00(\d+)\x00', lambda m: '<code class="ic">%s</code>' % codes[int(m.group(1))], s)
    return s


def is_block_start(l):
    l = l.lstrip()
    return bool(re.match(r'^```', l) or re.match(r'^#{1,6}\s', l) or re.match(r'^---+\s*$', l)
                or l.startswith('|') or l.startswith('>') or re.match(r'^([-*]|\d+\.)\s+', l))


def render_table(rows):
    def cells(r):
        r = r.strip()
        if r.startswith('|'):
            r = r[1:]
        if r.endswith('|'):
            r = r[:-1]
        return [c.strip() for c in r.split('|')]

    header = cells(rows[0])
    body = rows[2:] if len(rows) >= 2 else []
    th = ''.join('<th>%s</th>' % inline(c) for c in header)
    trs = ['<tr>%s</tr>' % ''.join('<td>%s</td>' % inline(c) for c in cells(r)) for r in body]
    return ('<div class="tablewrap"><table><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>'
            % (th, ''.join(trs)))


def convert(md):
    lines = md.split('\n')
    i, n, out, title = 0, len(md.split('\n')), [], None
    while i < n:
        line = lines[i]
        m = re.match(r'^```(\w*)\s*$', line)
        if m:
            lang = m.group(1)
            i += 1
            buf = []
            while i < n and not re.match(r'^```\s*$', lines[i]):
                buf.append(lines[i])
                i += 1
            i += 1
            code = html.escape('\n'.join(buf), quote=False)
            attr = ' data-lang="%s"' % lang if lang else ''
            out.append('<pre class="code"%s><code>%s</code></pre>' % (attr, code))
            continue
        if line.strip() == '':
            i += 1
            continue
        m = re.match(r'^(#{1,6})\s+(.*)$', line)
        if m:
            lv = len(m.group(1))
            txt = inline(m.group(2))
            if lv == 1 and title is None:
                title = re.sub('<[^>]+>', '', txt)
            out.append('<h%d>%s</h%d>' % (lv, txt, lv))
            i += 1
            continue
        if re.match(r'^---+\s*$', line):
            out.append('<hr>')
            i += 1
            continue
        if line.lstrip().startswith('|'):
            tbl = []
            while i < n and lines[i].lstrip().startswith('|'):
                tbl.append(lines[i])
                i += 1
            out.append(render_table(tbl))
            continue
        if line.lstrip().startswith('>'):
            buf = []
            while i < n and lines[i].lstrip().startswith('>'):
                buf.append(re.sub(r'^\s*>\s?', '', lines[i]))
                i += 1
            out.append('<blockquote>%s</blockquote>' % inline(' '.join(buf)))
            continue
        if re.match(r'^\s*([-*]|\d+\.)\s+', line):
            ordered = bool(re.match(r'^\s*\d+\.\s+', line))
            items = []
            while i < n and re.match(r'^\s*([-*]|\d+\.)\s+', lines[i]):
                content = re.sub(r'^\s*([-*]|\d+\.)\s+', '', lines[i])
                cb = re.match(r'^\[([ xX])\]\s+(.*)$', content)
                if cb:
                    items.append((True, cb.group(1).lower() == 'x', inline(cb.group(2))))
                else:
                    items.append((False, False, inline(content)))
                i += 1
            tag = 'ol' if ordered else 'ul'
            lis = []
            for is_task, done, txt in items:
                if is_task:
                    lis.append('<li class="task%s">%s</li>' % (' done' if done else '', txt))
                else:
                    lis.append('<li>%s</li>' % txt)
            cls = ' class="tasklist"' if any(t[0] for t in items) else ''
            out.append('<%s%s>%s</%s>' % (tag, cls, ''.join(lis), tag))
            continue
        buf = []
        while i < n and lines[i].strip() != '' and not is_block_start(lines[i]):
            buf.append(lines[i])
            i += 1
        out.append('<p>%s</p>' % inline(' '.join(buf)))
    return '\n'.join(out), (title or 'BeanProfile Document')


def crumb_for(md_path):
    try:
        rel = md_path.resolve().relative_to(ROOT).parent.as_posix()
        return 'BeanProfile · %s' % rel if rel and rel != '.' else 'BeanProfile'
    except ValueError:
        return 'BeanProfile'


def build(md_path):
    md = md_path.read_text(encoding='utf-8')
    body, title = convert(md)
    page = ('<title>%s</title>\n<style>%s</style>\n'
            '<article class="doc"><div class="crumb">%s</div>\n%s\n</article>'
            % (title, CSS, html.escape(crumb_for(md_path), quote=False), body))
    out_path = md_path.with_suffix('.html')
    out_path.write_text(page, encoding='utf-8')
    return out_path, title


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    if argv == ['--all']:
        targets = sorted((ROOT / 'docs').rglob('*.md'))
    else:
        targets = [pathlib.Path(a) for a in argv]
    if not targets:
        print('변환할 .md 파일이 없습니다.')
        return 1
    for md_path in targets:
        if not md_path.exists():
            print('건너뜀(없음): %s' % md_path)
            continue
        out_path, title = build(md_path)
        print('생성: %s  (제목: %s)' % (out_path.relative_to(ROOT) if out_path.is_relative_to(ROOT) else out_path, title))
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
