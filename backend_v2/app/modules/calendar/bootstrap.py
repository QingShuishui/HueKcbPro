import logging

from app.modules.calendar.service import ensure_current_academic_calendar


logger = logging.getLogger(__name__)


def main() -> None:
    try:
        calendar = ensure_current_academic_calendar()
        logger.info("academic calendar ready for term %s", calendar["term_id"])
    except Exception:
        # The API has a configured-date fallback and must remain available if HUE is down.
        logger.exception("unable to bootstrap the academic calendar")


if __name__ == "__main__":
    main()
