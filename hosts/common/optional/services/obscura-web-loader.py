import json
import os
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

obscura = os.environ["OBSCURA_BIN"]
fetch_timeout = int(os.environ["OBSCURA_FETCH_TIMEOUT"])
runtime_directory = os.environ["RUNTIME_DIRECTORY"]
fetch_slots = threading.BoundedSemaphore(2)
maximum_request_bytes = 1_048_576
maximum_urls = 20
maximum_url_length = 4096
maximum_content_characters = 200_000


def validate_url(url):
    if not isinstance(url, str) or len(url) > maximum_url_length:
        return False
    try:
        parsed = urlsplit(url)
        return (
            parsed.scheme in ("http", "https")
            and parsed.hostname is not None
            and parsed.username is None
            and parsed.password is None
            and (parsed.port is None or parsed.port > 0)
        )
    except ValueError:
        return False


def fetch(url):
    if not validate_url(url):
        return {"page_content": "", "metadata": {"source": url, "error": "Invalid URL"}}

    with fetch_slots, tempfile.TemporaryDirectory(dir=runtime_directory) as home:
        environment = os.environ.copy()
        environment["HOME"] = home
        try:
            result = subprocess.run(
                [
                    obscura,
                    "fetch",
                    url,
                    "--dump",
                    "markdown",
                    "--quiet",
                    "--obey-robots",
                    "--timeout",
                    str(fetch_timeout),
                    "--storage-dir",
                    home,
                ],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                timeout=fetch_timeout + 5,
                check=False,
                env=environment,
            )
        except subprocess.TimeoutExpired:
            return {"page_content": "", "metadata": {"source": url, "error": "Fetch timed out"}}
        except OSError:
            return {"page_content": "", "metadata": {"source": url, "error": "Fetch could not start"}}

    if result.returncode != 0:
        return {"page_content": "", "metadata": {"source": url, "error": "Fetch failed"}}

    return {
        "page_content": result.stdout[:maximum_content_characters],
        "metadata": {"source": url},
    }


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/":
            self.send_error(404)
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            if content_length <= 0 or content_length > maximum_request_bytes:
                self.send_error(413)
                return
            payload = json.loads(self.rfile.read(content_length))
            urls = payload.get("urls") if isinstance(payload, dict) else None
            if not isinstance(urls, list) or not urls or len(urls) > maximum_urls:
                self.send_error(400)
                return
            results = [fetch(url) for url in urls]
            response = json.dumps(results, ensure_ascii=False).encode("utf-8")
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError):
            self.send_error(400)
            return

        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        self.wfile.write(response)

    def log_message(self, format, *args):
        return


ThreadingHTTPServer(("127.0.0.1", int(os.environ["OBSCURA_PORT"])), Handler).serve_forever()
