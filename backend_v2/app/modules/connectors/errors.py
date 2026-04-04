class ConnectorError(Exception):
    """Base connector error."""


class InvalidCredentialsError(ConnectorError):
    """Raised when academic credentials are invalid."""
