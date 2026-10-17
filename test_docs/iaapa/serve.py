#!/usr/bin/env python3
"""Local dev server with aggressive no-cache headers.

Use instead of `python3 -m http.server 8766` while editing the book.
Every response carries Cache-Control: no-store so browsers always
re-fetch — fixes the "I edited the file but Safari/Chrome still
show the old version" problem.

Run from the book/ folder:
    python3 serve.py [port]    # default port 8766

Then open http://localhost:8766/book_en_skinned.html
"""

import http.server
import socketserver
import sys


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Tell every browser that nothing is cacheable.
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8766
    # Bind to 127.0.0.1 only (not 0.0.0.0) so the dev server isn't reachable
    # from other devices on the LAN. Localhost-only by design.
    with socketserver.TCPServer(('127.0.0.1', port), NoCacheHandler) as httpd:
        print(f'Serving with no-cache headers at http://localhost:{port}')
        print('Ctrl-C to stop.')
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print('\nStopped.')


if __name__ == '__main__':
    main()
