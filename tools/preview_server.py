"""Local preview server for phones on the same Wi-Fi.

Serves the Flutter web build and forwards /api/* and /actuator/* to the backend on localhost:8080, so a phone only
needs to reach this one port (no CORS, no second address). Development use only - no TLS, no authentication.

    python tools/preview_server.py [web_dir] [port]
"""
import http.server
import socketserver
import sys
import urllib.error
import urllib.request

WEB_DIR = sys.argv[1] if len(sys.argv) > 1 else "apps/mobile/build/web"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8081
BACKEND = "http://127.0.0.1:8080"
# origin/referer are dropped: the browser sees one origin (this server), so the backend must not treat the
# forwarded call as cross-origin and reject it against its CORS allow-list.
HOP = {"connection", "keep-alive", "transfer-encoding", "te", "trailer", "upgrade", "proxy-authorization",
       "proxy-authenticate", "host", "content-length", "origin", "referer"}


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def _proxy(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None
        req = urllib.request.Request(BACKEND + self.path, data=body, method=self.command)
        for k, v in self.headers.items():
            if k.lower() not in HOP:
                req.add_header(k, v)
        req.add_header("X-Forwarded-For", self.client_address[0])  # real client, so limits are per device
        try:
            resp = urllib.request.urlopen(req, timeout=30)
        except urllib.error.HTTPError as e:
            resp = e
        except Exception:
            self.send_error(502, "Backend unreachable")
            return
        data = resp.read()
        self.send_response(resp.status if hasattr(resp, "status") else resp.code)
        for k, v in resp.headers.items():
            if k.lower() not in HOP:
                self.send_header(k, v)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _is_api(self):
        return self.path.startswith(("/api/", "/actuator/", "/media/"))

    def do_GET(self):
        self._proxy() if self._is_api() else super().do_GET()

    def do_POST(self):
        self._proxy()

    def do_PUT(self):
        self._proxy()

    def do_PATCH(self):
        self._proxy()

    def do_DELETE(self):
        self._proxy()


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    print(f"Serving {WEB_DIR} on 0.0.0.0:{PORT}, proxying API to {BACKEND}", flush=True)
    Server(("0.0.0.0", PORT), Handler).serve_forever()
