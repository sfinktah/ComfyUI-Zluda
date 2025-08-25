# python
import argparse
import json
import re
import sys
import os
import zipfile
from html.parser import HTMLParser
from xml.etree import ElementTree as ET

ANSI_RESET = "\x1b[0m"
ANSI_BOLD = "\x1b[1m"
ANSI_DIM = "\x1b[2m"
ANSI_ITALIC = "\x1b[3m"
ANSI_UNDERLINE = "\x1b[4m"
ANSI_REVERSE = "\x1b[7m"
ANSI_CODE = "\x1b[38;5;244m"  # gray-ish for code text

ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")

BLOCK_TAGS = {
    "p", "div", "br", "li", "ul", "ol",
    "h1", "h2", "h3", "h4", "h5", "h6",
    "blockquote", "pre",
}

INLINE_STYLES = {
    "strong": ANSI_BOLD,
    "b": ANSI_BOLD,
    "em": ANSI_ITALIC,
    "i": ANSI_ITALIC,
    "u": ANSI_UNDERLINE,
    "code": ANSI_CODE,
    "tt": ANSI_CODE,
    "kbd": ANSI_REVERSE,
    "samp": ANSI_CODE,
    "a": ANSI_UNDERLINE,  # underline links
}

HEADING_STYLES = {
    "h1": ANSI_BOLD,
    "h2": ANSI_BOLD,
    "h3": ANSI_BOLD,
    "h4": ANSI_BOLD,
    "h5": ANSI_BOLD,
    "h6": ANSI_BOLD,
}

def visible_len(s: str) -> int:
    return len(ANSI_RE.sub("", s))

def wrap_ansi(text: str, width: int) -> list[str]:
    """Wrap text containing ANSI sequences by visible width."""
    def ends_with_visible_space(s: str) -> bool:
        vis = ANSI_RE.sub("", s)
        return bool(vis) and vis[-1].isspace()

    lines = []
    for paragraph in text.splitlines():
        if not paragraph.strip():
            lines.append("")
            continue
        words = re.findall(r"\x1b\[[0-9;]*m|\S+|\s+", paragraph)
        line = ""
        cur_len = 0  # visible length
        for tok in words:
            if ANSI_RE.fullmatch(tok):
                # ANSI codes do not affect visible width
                line += tok
                continue
            # Preserve whitespace tokens but collapse to a single visible space
            if tok.isspace():
                if cur_len == 0 or ends_with_visible_space(line):
                    # avoid leading or duplicate spaces
                    continue
                line += " "
                cur_len += 1
                continue
            # It's a word (may include punctuation)
            wlen = len(tok)
            if cur_len == 0:
                # start line
                if wlen <= width:
                    line += tok
                    cur_len = wlen
                else:
                    # hard-wrap long word
                    start = 0
                    while start < wlen:
                        chunk = tok[start:start + max(1, width)]
                        lines.append(chunk)
                        start += width
                    line = ""
                    cur_len = 0
            else:
                # add a space only if we don't already end with one (visibly)
                last_is_space = ends_with_visible_space(line)
                sep = "" if last_is_space else " "
                add_len = (0 if last_is_space else 1) + wlen
                if cur_len + add_len <= width:
                    line += sep + tok
                    cur_len += add_len
                else:
                    # emit current line
                    lines.append(line.rstrip())
                    line = tok
                    cur_len = wlen
        if line:
            lines.append(line.rstrip())
    return lines

class AnsiHTMLToText(HTMLParser):
    """
    Convert XHTML to ANSI-decorated text with simple block handling.
    Produces paragraphs separated by newlines; later wrapped/paginated.
    """
    def __init__(self):
        super().__init__()
        self.buffer: list[str] = []
        self.open_styles: list[str] = []
        self.in_pre = False
        self.list_stack: list[str] = []
        self.list_item_index_stack: list[int] = []

    def push_style(self, code: str):
        self.open_styles.append(code)
        self.buffer.append(code)

    def reapply_styles(self):
        # Reapply all currently open styles
        for s in self.open_styles:
            self.buffer.append(s)

    def pop_style_for_tag(self, tag: str):
        # Close tag: reset, then reapply other open styles
        if tag in INLINE_STYLES or tag in HEADING_STYLES or tag in {"a", "code", "tt", "kbd", "samp"}:
            if self.open_styles:
                self.buffer.append(ANSI_RESET)
                # Remove the most recent matching style if present
                # For simplicity, drop one style from the end
                try:
                    self.open_styles.pop()
                except IndexError:
                    pass
                self.reapply_styles()

    def newline(self, count: int = 1):
        self.buffer.append("\n" * max(1, count))

    def handle_starttag(self, tag, attrs):
        t = tag.lower()
        if t == "br":
            self.newline()
            return

        if t in {"ul", "ol"}:
            self.list_stack.append(t)
            self.list_item_index_stack.append(0)

        if t == "li":
            if self.list_stack:
                kind = self.list_stack[-1]
                if kind == "ol":
                    self.list_item_index_stack[-1] += 1
                    idx = self.list_item_index_stack[-1]
                    bullet = f"{idx}."
                else:
                    bullet = "•"
                self.buffer.append("\n" + bullet + " ")
            else:
                self.buffer.append("\n- ")
            return

        if t == "blockquote":
            self.push_style(ANSI_DIM + ANSI_ITALIC)
            self.newline()

        if t == "pre":
            self.in_pre = True
            self.push_style(ANSI_CODE)
            self.newline()

        # Headings -> bold + underline + blank lines
        if t in HEADING_STYLES:
            self.newline(2)
            self.push_style(HEADING_STYLES[t] + ANSI_UNDERLINE)
            return

        # Inline emphasis
        if t in INLINE_STYLES:
            self.push_style(INLINE_STYLES[t])
            return

        if t in {"p", "div"}:
            self.newline()

    def handle_endtag(self, tag):
        t = tag.lower()

        if t in {"ul", "ol"}:
            if self.list_stack:
                self.list_stack.pop()
            if self.list_item_index_stack:
                self.list_item_index_stack.pop()
            self.newline()

        if t == "li":
            self.newline()

        if t == "blockquote":
            self.pop_style_for_tag(t)
            self.newline()

        if t == "pre":
            self.in_pre = False
            self.pop_style_for_tag(t)
            self.newline(2)

        if t in HEADING_STYLES:
            self.pop_style_for_tag(t)
            self.newline(2)

        if t in INLINE_STYLES:
            self.pop_style_for_tag(t)

        if t in {"p", "div"}:
            self.newline()

    def handle_data(self, data):
        if not data:
            return
        if self.in_pre:
            # Preserve whitespace in <pre>
            self.buffer.append(data)
            return
        # Normalize punctuation: em-dash to " -- ", curly apostrophes to straight, ellipsis to "..."
        text = data.replace("\u2014", " -- ")
        text = text.replace("\u2019", "'").replace("\u2018", "'")
        text = text.replace("\u2026", "...")
        # Collapse internal whitespace
        s = " ".join(text.split())
        # Ensure no space before ellipsis
        s = re.sub(r"\s+\.\.\.", "...", s)
        if s:
            self.buffer.append(s + " ")

    def get_text(self) -> str:
        text = "".join(self.buffer)
        # Trim trailing spaces on lines, collapse 3+ newlines to 2
        text = "\n".join(line.rstrip() for line in text.splitlines())
        text = re.sub(r"\n{3,}", "\n\n", text)
        # Ensure final reset
        if not text.endswith(ANSI_RESET):
            text += ANSI_RESET
        return text

def read_text_from_xhtml(xhtml_bytes: bytes) -> str:
    parser = AnsiHTMLToText()
    parser.feed(xhtml_bytes.decode("utf-8", errors="ignore"))
    return parser.get_text()

def parse_epub(epub_path: str) -> dict:
    with zipfile.ZipFile(epub_path, "r") as zf:
        container_xml = zf.read("META-INF/container.xml")
        root = ET.fromstring(container_xml)
        ns = {"cn": "urn:oasis:names:tc:opendocument:xmlns:container"}
        opf_path = root.find(".//cn:rootfile", ns).attrib["full-path"]

        opf_xml = zf.read(opf_path)
        opf = ET.fromstring(opf_xml)

        ns2 = {
            "opf": opf.tag.split('}')[0].strip('{'),
            "dc": "http://purl.org/dc/elements/1.1/",
        }

        metadata = {}
        for tag in ("title", "creator", "language", "publisher", "date", "identifier"):
            el = opf.find(f".//dc:{tag}", ns2)
            if el is not None and (txt := (el.text or "").strip()):
                metadata[tag] = txt

        manifest = {}
        for item in opf.findall(".//opf:manifest/opf:item", ns2):
            item_id = item.attrib.get("id")
            href = item.attrib.get("href")
            mediatype = item.attrib.get("media-type")
            if item_id and href:
                manifest[item_id] = {"href": href, "media_type": mediatype}

        spine_ids = [it.attrib["idref"] for it in opf.findall(".//opf:spine/opf:itemref", ns2)]

        base_dir = ""
        if "/" in opf_path:
            base_dir = opf_path.rsplit("/", 1)[0] + "/"

        chapters = []
        for i, item_id in enumerate(spine_ids):
            meta = manifest.get(item_id)
            if not meta:
                continue
            href = meta["href"]
            path = base_dir + href
            try:
                data = zf.read(path)
            except KeyError:
                continue
            if (meta["media_type"] or "").endswith(("xhtml+xml", "html")):
                text = read_text_from_xhtml(data)
                chapters.append({
                    "index": i,
                    "id": item_id,
                    "href": href,
                    "text": text,
                })

        return {
            "metadata": metadata,
            "spine": spine_ids,
            "chapters": chapters,
        }

def paginate_lines(lines: list[str], lines_per_page: int) -> list[list[str]]:
    pages = []
    for i in range(0, len(lines), lines_per_page):
        pages.append(lines[i:i + lines_per_page])
    return pages

def _resume_file_path() -> str:
    return os.path.join(os.path.expanduser("~"), ".gideon")

def _read_resume_page() -> int | None:
    try:
        with open(_resume_file_path(), "r", encoding="utf-8") as f:
            s = f.read().strip()
            if s:
                return int(s)
    except (FileNotFoundError, ValueError, OSError):
        return None
    return None

def _write_resume_page(page_num: int) -> None:
    try:
        with open(_resume_file_path(), "w", encoding="utf-8") as f:
            f.write(str(page_num))
    except OSError:
        # Silently ignore persistence errors
        pass

def main():
    ap = argparse.ArgumentParser(description="EPUB to JSON and ANSI-formatted text with pagination.")
    ap.add_argument("epub", help="Path to .epub file")
    ap.add_argument("--width", type=int, default=120, help="Wrap width for terminal (default: 120)")
    ap.add_argument("--lines-per-page", type=int, default=40, help="Number of wrapped lines per page (default: 40)")
    ap.add_argument("--page", type=int, help="1-based page number to print (only prints that page of plain text)")
    ap.add_argument(
        "--resume",
        action="store_true",
        help="Resume from last saved page in ~/.gideon; prints one page and advances"
    )
    ap.add_argument(
        "--reset",
        action="store_true",
        help="Reset ~/.gideon to the current page argument (or 1 if omitted)"
    )
    args = ap.parse_args()

    book = parse_epub(args.epub)

    # 1) Emit JSON to stdout first
    # print(json.dumps(book, ensure_ascii=False, indent=2))

    # 2) ANSI-formatted plain text with wrapping and pagination
    # print("\n=== PLAIN TEXT OUTPUT ===\n")

    title = book.get("metadata", {}).get("title", "Untitled")
    heading = f"{ANSI_BOLD}{title}{ANSI_RESET}"
    all_text_parts = [heading]

    for ch in book["chapters"]:
        ch_title = f"{ANSI_UNDERLINE}Chapter {ch['index'] + 1}{ANSI_RESET} ({ch['href']})"
        all_text_parts.append("\n" + ch_title + "\n")
        all_text_parts.append(ch["text"])

    combined = "\n".join(all_text_parts)

    # Wrap by visible width, preserving ANSI
    wrapped_lines = wrap_ansi(combined, args.width)

    # Paginate into virtual pages
    pages = paginate_lines(wrapped_lines, args.lines_per_page)

    if not pages:
        print("(No content)")
        return

    # If requested, reset the resume file to the specified page (or 1)
    if args.reset:
        init_page = args.page if args.page else 1
        _write_resume_page(init_page)

    if args.resume:
        # Read or initialize the resume page
        stored = _read_resume_page()
        if stored is None:
            # Initialize to the page specified on the command line (or 1 if not provided)
            init_page = args.page if args.page else 1
            _write_resume_page(init_page)
            stored = init_page
        # Clamp to a valid range
        if stored < 1 or stored > len(pages):
            stored = 1
        page_idx = stored - 1
        print(f"[Page {stored}/{len(pages)} | width={args.width}, lines/page={args.lines_per_page}]")
        print("\n".join(pages[page_idx]) + ANSI_RESET)
        # Advance the stored page for next resume
        next_page = stored + 1
        if next_page > len(pages):
            next_page = 1
        _write_resume_page(next_page)
    elif args.page:
        page_idx = args.page - 1
        if page_idx < 0 or page_idx >= len(pages):
            print(f"Requested page {args.page} is out of range (1..{len(pages)}).")
            return
        print(f"[Page {args.page}/{len(pages)} | width={args.width}, lines/page={args.lines_per_page}]")
        print("\n".join(pages[page_idx]) + ANSI_RESET)
    else:
        # Print all pages
        for i, pg in enumerate(pages, start=1):
            header = f"[Page {i}/{len(pages)} | width={args.width}, lines/page={args.lines_per_page}]"
            print(header)
            print("\n".join(pg) + ANSI_RESET)
            if i != len(pages):
                print("\n" + "-" * min(args.width, 80) + "\n")

if __name__ == "__main__":
    main()