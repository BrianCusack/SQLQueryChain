import logging
import colorlog

# Define agent-specific colors
AGENT_COLORS = {
    "question_generator": "purple",
    "sql_formulator": "green",
    "query_executor": "blue",
    "main": "red",
}


def setup_logger(name: str) -> logging.Logger:
    """Set up a colored logger with consistent formatting."""
    logger = logging.getLogger(name)

    # Only add handler if logger doesn't already have handlers
    if not logger.handlers:
        handler = colorlog.StreamHandler()

        # Get agent name from module path (last part of the path)
        agent_name = name.split(".")[-1]
        agent_color = AGENT_COLORS.get(agent_name, "white")

        handler.setFormatter(
            colorlog.ColoredFormatter(
                f"%(log_color)s[{agent_name}] %(asctime)s - %(levelname)s - %(message)s",
                log_colors={
                    "DEBUG": agent_color,
                    "INFO": agent_color,
                    "WARNING": "yellow",
                    "ERROR": "red",
                    "CRITICAL": "red,bg_white",
                },
                datefmt="%Y-%m-%d %H:%M:%S",
            )
        )
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)

    return logger
