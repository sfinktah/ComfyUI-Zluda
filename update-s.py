#!/usr/bin/env python3
"""
GitHub repo file/directory updater.

Synchronizes a specified list of files and/or directories from a given GitHub
repository and branch into a local destination directory using the GitHub API.
Only updates files when content changes.

Usage examples:
- Sync a single file:
  python github_update.py --repo owner/repo --branch main --dest ./vendor --path path/in/repo/file.txt

- Sync multiple files and directories (directories are recursive):
  python github_update.py --repo owner/repo --branch main --dest ./vendor \
      --path dir/subdir --path scripts/tool.py

- Use a token from environment:
  set GITHUB_TOKEN=ghp_xxx (Windows) or export GITHUB_TOKEN=ghp_xxx (Unix)
  python github_update.py --repo owner/repo --dest ./vendor --path config --path README.md

Notes:
- Directories are detected via the GitHub contents API and traversed recursively.
- Token is optional for public repos but strongly recommended to avoid rate limiting.
"""

from __future__ import annotations

import argparse
import base64
import os
import sys
import time
import subprocess
import tempfile
from typing import Iterable, List, Optional, Tuple

import requests
from urllib.parse import quote


GITHUB_API = "https://api.github.com"


class GitHubSyncError(Exception):
    pass


def _auth_headers(token: Optional[str], accept: Optional[str] = None) -> dict:
    headers = {
        "User-Agent": "github-update-script/1.0",
        "Accept": accept or "application/vnd.github+json",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def _check_rate_limit(resp: requests.Response, wait_on_limit: bool) -> None:
    if resp.status_code != 403:
        return
    remaining = resp.headers.get("X-RateLimit-Remaining")
    if remaining == "0":
        reset = resp.headers.get("X-RateLimit-Reset")
        if not wait_on_limit:
            raise GitHubSyncError(
                "GitHub API rate limit exceeded. Provide a token, wait, or use --wait-on-rate-limit."
            )
        if reset is not None:
            try:
                reset_ts = int(reset)
            except ValueError:
                raise GitHubSyncError("Rate limited and could not parse reset time.")
            sleep_for = max(0, reset_ts - int(time.time()) + 2)
            print(f"Rate limit reached. Waiting {sleep_for}s until reset...", file=sys.stderr)
            time.sleep(sleep_for)
        else:
            # No reset info; conservative backoff
            backoff = 60
            print(f"Rate limit reached. Waiting {backoff}s...", file=sys.stderr)
            time.sleep(backoff)


def _request_with_rate_handling(
    method: str,
    url: str,
    headers: dict,
    params: Optional[dict] = None,
    stream: bool = False,
    max_retries: int = 2,
) -> requests.Response:
    attempt = 0
    while True:
        resp = requests.request(method, url, headers=headers, params=params, stream=stream)
        if resp.status_code in (500, 502, 503, 504):
            if attempt >= max_retries:
                return resp
            attempt += 1
            time.sleep(1.5 * attempt)
            continue
        return resp


def list_dir_contents(
    owner: str,
    repo: str,
    path: str,
    ref: str,
    token: Optional[str],
    wait_on_rate_limit: bool,
) -> List[dict]:
    # GET /repos/{owner}/{repo}/contents/{path}?ref=branch
    qp = quote(path.lstrip("/"), safe="/")
    url = f"{GITHUB_API}/repos/{owner}/{repo}/contents/{qp}"
    headers = _auth_headers(token)
    params = {"ref": ref}
    while True:
        resp = _request_with_rate_handling("GET", url, headers=headers, params=params)
        if resp.status_code == 404:
            # Skip missing paths with a simple warning
            print(f"Warning: remote path not found: {path} (ref={ref}); skipping.", file=sys.stderr)
            return []
        if resp.status_code == 403:
            _check_rate_limit(resp, wait_on_limit=wait_on_rate_limit)
            if resp.status_code == 403:
                # If not waiting or still failing, raise
                raise GitHubSyncError(f"Access denied or rate limited: {url} ({resp.text})")
            continue
        if not resp.ok:
            raise GitHubSyncError(f"Failed to list contents for {path}: {resp.status_code} {resp.text}")
        data = resp.json()
        if isinstance(data, list):
            return data
        # Single file case: return as a "list" with that one file-like dict
        if isinstance(data, dict) and data.get("type") == "file":
            return [data]
        if isinstance(data, dict) and data.get("type") == "dir":
            # Some responses may return dict for dir? Generally list, but guard anyway
            return data.get("entries", [])
        raise GitHubSyncError(f"Unexpected response for {path}: {data}")


def download_file_raw(
    owner: str,
    repo: str,
    path: str,
    ref: str,
    token: Optional[str],
    wait_on_rate_limit: bool,
) -> bytes:
    # GET raw content via contents API
    qp = quote(path.lstrip("/"), safe="/")
    url = f"{GITHUB_API}/repos/{owner}/{repo}/contents/{qp}"
    headers = _auth_headers(token, accept="application/vnd.github.raw")
    params = {"ref": ref}
    while True:
        resp = _request_with_rate_handling("GET", url, headers=headers, params=params, stream=False)
        if resp.status_code == 404:
            raise GitHubSyncError(f"File not found: {path} (ref={ref})")
        if resp.status_code == 403:
            _check_rate_limit(resp, wait_on_limit=wait_on_rate_limit)
            if resp.status_code == 403:
                raise GitHubSyncError(f"Access denied or rate limited while downloading {path}")
            continue
        if not resp.ok:
            raise GitHubSyncError(f"Failed to download {path}: {resp.status_code} {resp.text}")
        return resp.content


def is_directory_item(item: dict) -> bool:
    return item.get("type") == "dir"


def is_file_item(item: dict) -> bool:
    return item.get("type") == "file"


def walk_remote(
    owner: str,
    repo: str,
    base_path: str,
    ref: str,
    token: Optional[str],
    wait_on_rate_limit: bool,
) -> Iterable[str]:
    """
    Yield file paths (relative to repo root) for all files under base_path.
    If base_path is a file, yields that single file path.
    """
    items = list_dir_contents(owner, repo, base_path, ref, token, wait_on_rate_limit)
    # If the result is a single file described as dict (len==1 and type file), great.
    # Otherwise, it's a directory listing.
    if len(items) == 1 and items[0].get("type") == "file" and items[0].get("path") == items[0].get("path"):
        # Single file
        yield items[0]["path"]
        return

    # Directory listing (or mixed)
    for item in items:
        if is_file_item(item):
            yield item["path"]
        elif is_directory_item(item):
            yield from walk_remote(
                owner, repo, item["path"], ref, token, wait_on_rate_limit
            )
        else:
            # Skip symlinks/submodules for safety
            continue


def ensure_parent_dir(path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)


def read_local_bytes(path: str) -> Optional[bytes]:
    try:
        with open(path, "rb") as f:
            return f.read()
    except FileNotFoundError:
        return None


def atomic_write(path: str, data: bytes) -> None:
    ensure_parent_dir(path)
    tmp_path = f"{path}.tmp~"
    with open(tmp_path, "wb") as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())
    # Replace atomically where possible
    if os.path.exists(path):
        os.replace(tmp_path, path)
    else:
        os.rename(tmp_path, path)

# Marker tokens for .bat files to preserve local content between them.
# Usage in .bat files (case-insensitive, anywhere on the line, typically in comments):
#   REM NO-UPDATE-START
#   ... user-customized content to keep locally ...
#   REM NO-UPDATE-END
_BAT_MARKER_START = "-----BEGIN USER SECTION-----"
_BAT_MARKER_END = "-----END USER SECTION-----"


def _decode_text_best_effort(data: bytes) -> Tuple[str, str]:
    """
    Decode bytes to text with a reasonable fallback for Windows batch files.
    Returns (text, encoding_used).
    """
    for enc in ("utf-8-sig", "utf-8", "cp1252"):
        try:
            return data.decode(enc), enc
        except Exception:
            continue
    # Last resort: replace errors under cp1252
    return data.decode("cp1252", errors="replace"), "cp1252"


def _find_marker_blocks(lines: List[str]) -> List[Tuple[int, int]]:
    """
    Scan list of lines (with line endings preserved) and find non-nested
    blocks delimited by start/end markers. Returns list of (start_idx, end_idx)
    where indices refer to the marker lines themselves in 'lines'.
    """
    starts: List[int] = []
    blocks: List[Tuple[int, int]] = []
    start_token = _BAT_MARKER_START.lower()
    end_token = _BAT_MARKER_END.lower()
    for i, ln in enumerate(lines):
        low = ln.lower()
        if start_token in low:
            starts.append(i)
        elif end_token in low and starts:
            s = starts.pop(0)
            blocks.append((s, i))
    return blocks


def merge_protected_bat_sections(local_bytes: bytes, remote_bytes: bytes) -> bytes:
    """
    Merge remote .bat content with local protected regions:
    - If remote content contains marker pairs, for each block, replace its inner
      content with the corresponding local block content (by order), if present.
    - Markers themselves remain as in the remote.
    - If no markers are found in the remote, returns remote_bytes unchanged.
    """
    remote_text, remote_enc = _decode_text_best_effort(remote_bytes)
    local_text, _local_enc = _decode_text_best_effort(local_bytes)

    remote_lines = remote_text.splitlines(True)  # keepends
    local_lines = local_text.splitlines(True)

    r_blocks = _find_marker_blocks(remote_lines)
    if not r_blocks:
        return remote_bytes
    l_blocks = _find_marker_blocks(local_lines)

    # Build merged content using remote as baseline.
    merged_lines: List[str] = []
    last_end = -1
    for idx, (rs, re) in enumerate(r_blocks):
        # Up to and including start marker from remote
        merged_lines.extend(remote_lines[last_end + 1 : rs + 1])

        # Body: prefer local content inside markers if available
        if idx < len(l_blocks):
            ls, le = l_blocks[idx]
            merged_lines.extend(local_lines[ls + 1 : le])
        else:
            merged_lines.extend(remote_lines[rs + 1 : re])

        # End marker line from remote
        merged_lines.append(remote_lines[re])
        last_end = re

    # Tail after the last block
    merged_lines.extend(remote_lines[last_end + 1 :])

    merged_text = "".join(merged_lines)
    try:
        return merged_text.encode(remote_enc)
    except Exception:
        # Fallback to utf-8 if encoding back with remote encoding fails
        return merged_text.encode("utf-8")



def is_self_target(local_path: str) -> bool:
    """
    Returns True if local_path points to this running script.
    Uses robust path comparison for Windows and non-Windows.
    """
    candidates = []
    try:
        candidates.append(os.path.abspath(__file__))
    except Exception:
        pass
    try:
        candidates.append(os.path.abspath(sys.argv[0]))
    except Exception:
        pass

    target = os.path.abspath(local_path)
    for p in candidates:
        try:
            # Prefer samefile when possible
            if os.path.exists(p) and os.path.exists(target) and os.path.samefile(p, target):
                return True
        except Exception:
            pass
        # Fallback: normalized, case-insensitive compare on Windows
        if os.path.normcase(os.path.normpath(p)) == os.path.normcase(os.path.normpath(target)):
            return True
    return False


def schedule_windows_deferred_replace(target_path: str, data: bytes) -> None:
    """
    On Windows, stage 'data' to a temp dir and spawn a small .bat that will
    replace target_path after this process exits.
    """
    tempdir = tempfile.mkdtemp(prefix="update-s-self-")
    staged_path = os.path.join(tempdir, os.path.basename(target_path))
    ensure_parent_dir(staged_path)
    with open(staged_path, "wb") as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())

    replacer = os.path.join(tempdir, "replace_self.bat")
    target_q = f'"{os.path.abspath(target_path)}"'
    staged_q = f'"{staged_path}"'
    tempdir_q = f'"{tempdir}"'
    script = "\n".join([
        "@echo off",
        "setlocal enableextensions",
        "timeout /t 1 /nobreak >nul",
        ":retry",
        f'move /y {target_q} {target_q}.old >nul 2>&1',
        "if errorlevel 1 (",
        "  timeout /t 1 /nobreak >nul",
        "  goto :retry",
        ")",
        f"move /y {staged_q} {target_q} >nul",
        f"del /q {target_q}.old >nul 2>&1",
        f"rd /s /q {tempdir_q} >nul 2>&1",
    ])
    with open(replacer, "w", encoding="utf-8", newline="\r\n") as f:
        f.write(script)

    # Launch the replacer detached
    try:
        subprocess.Popen(["cmd", "/c", "start", "", replacer], close_fds=False)
    except Exception:
        # Best effort: try synchronous as a fallback
        subprocess.Popen([replacer], shell=True)


def sync_paths(
    repo: str,
    ref: str,
    dest: str,
    paths: List[str],
    token: Optional[str],
    dry_run: bool,
    wait_on_rate_limit: bool,
) -> Tuple[int, int, int]:
    """
    Returns a tuple: (updated_count, created_count, skipped_count)
    """
    if "/" not in repo:
        raise GitHubSyncError(f"--repo must be in 'owner/repo' format. Got: {repo}")
    owner, repo_name = repo.split("/", 1)

    updated = 0
    created = 0
    skipped = 0

    for p in paths:
        norm = p.strip().lstrip("/")
        if not norm:
            print("Skipping empty path specification.", file=sys.stderr)
            continue

        try:
            for file_path in walk_remote(owner, repo_name, norm, ref, token, wait_on_rate_limit):
                rel = file_path.lstrip("/")
                local_path = os.path.join(dest, rel)
                try:
                    remote_bytes = download_file_raw(owner, repo_name, file_path, ref, token, wait_on_rate_limit)
                except GitHubSyncError as e:
                    # Skip missing or inaccessible files with a warning
                    print(f"Warning: {e}", file=sys.stderr)
                    continue
                local_bytes = read_local_bytes(local_path)

                # Compute planned bytes, preserving protected regions in .bat files if present.
                planned_bytes = remote_bytes
                if local_bytes is not None and local_path.lower().endswith(".bat"):
                    try:
                        planned_bytes = merge_protected_bat_sections(local_bytes, remote_bytes)
                    except Exception:
                        # On any unexpected merge error, fall back to remote bytes
                        planned_bytes = remote_bytes

                if local_bytes is not None and local_bytes == planned_bytes:
                    skipped += 1
                    print(f"Up-to-date: {rel}")
                    continue

                if dry_run:
                    action = "Would create" if local_bytes is None else "Would update"
                    print(f"{action}: {rel}")
                    continue

                # Special handling: safely self-update on Windows by deferring replacement
                if os.name == "nt" and is_self_target(local_path):
                    try:
                        schedule_windows_deferred_replace(local_path, planned_bytes)
                        if local_bytes is None:
                            created += 1
                            print(f"Scheduled create (self): {rel}")
                        else:
                            updated += 1
                            print(f"Scheduled update (self): {rel}")
                    except Exception as e:
                        print(f"Warning: could not schedule self-update for {rel}: {e}", file=sys.stderr)
                    continue

                try:
                    atomic_write(local_path, planned_bytes)
                except PermissionError as e:
                    print(f"Warning: could not update {rel}: {e}", file=sys.stderr)
                    continue
                except OSError as e:
                    # On Windows, in-use files may raise sharing violations (winerror 32) or access denied (5)
                    if getattr(e, "winerror", None) in (5, 32):
                        print(f"Warning: could not update {rel} (possibly in use): {e}", file=sys.stderr)
                        continue
                    raise

                if local_bytes is None:
                    created += 1
                    print(f"Created: {rel}")
                else:
                    updated += 1
                    print(f"Updated: {rel}")

        except GitHubSyncError as e:
            raise
        except Exception as e:
            raise GitHubSyncError(f"Unexpected error while processing '{p}': {e}") from e

    return updated, created, skipped


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Update files/directories from a GitHub repo/branch into a local directory using the GitHub API."
    )
    parser.add_argument("--repo", required=True, help="Repository in the form owner/repo.")
    parser.add_argument("--branch", default="main", help="Branch or tag to use (default: main).")
    parser.add_argument("--dest", required=True, help="Local destination directory.")
    parser.add_argument(
        "--path",
        action="append",
        dest="paths",
        required=True,
        help="Path in the repo to sync (file or directory). Can be specified multiple times.",
    )
    parser.add_argument(
        "--token",
        default=os.environ.get("GITHUB_TOKEN"),
        help="GitHub token (or set GITHUB_TOKEN env var). Optional for public repos.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would change without writing files.",
    )
    parser.add_argument(
        "--wait-on-rate-limit",
        action="store_true",
        help="Wait until rate limit resets instead of failing immediately.",
    )
    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)

    dest = os.path.abspath(args.dest)
    os.makedirs(dest, exist_ok=True)

    try:
        updated, created, skipped = sync_paths(
            repo=args.repo,
            ref=args.branch,
            dest=dest,
            paths=args.paths,
            token=args.token,
            dry_run=args.dry_run,
            wait_on_rate_limit=args.wait_on_rate_limit,
        )
        print(
            f"Done. Created: {created}, Updated: {updated}, Unchanged: {skipped}."
        )
        return 0
    except GitHubSyncError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
