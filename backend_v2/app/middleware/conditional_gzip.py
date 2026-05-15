from collections.abc import Iterable

from starlette.middleware.gzip import GZipMiddleware
from starlette.types import ASGIApp, Receive, Scope, Send


class ConditionalGZipMiddleware:
    def __init__(
        self,
        app: ASGIApp,
        *,
        minimum_size: int = 500,
        excluded_path_prefixes: Iterable[str] = (),
    ) -> None:
        self.app = app
        self.gzip_app = GZipMiddleware(app, minimum_size=minimum_size)
        self.excluded_path_prefixes = tuple(excluded_path_prefixes)

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.gzip_app(scope, receive, send)
            return

        path = scope.get("path", "")
        if path.startswith(self.excluded_path_prefixes):
            await self.app(scope, receive, send)
            return

        await self.gzip_app(scope, receive, send)
