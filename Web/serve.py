"""Serves the Web directory, sending a pre-compressed `.gz` sibling when the client accepts gzip.

Usage: python3 Web/serve.py [port]
"""

import http.server
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".bin": "application/octet-stream",
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def send_head(self):
        path = self.translate_path(self.path)
        compressed = path + ".gz"
        if "gzip" in self.headers.get("Accept-Encoding", "") and os.path.isfile(compressed):
            with open(compressed, "rb") as file:
                size = os.fstat(file.fileno()).st_size
                self.send_response(200)
                self.send_header("Content-Type", self.guess_type(path))
                self.send_header("Content-Encoding", "gzip")
                self.send_header("Content-Length", str(size))
                self.end_headers()
                return open(compressed, "rb")
        return super().send_head()

    def list_directory(self, path):
        self.send_error(404)
        return None


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    http.server.ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
