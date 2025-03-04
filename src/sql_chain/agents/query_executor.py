from typing import Dict, Any
import json

from sql_chain.sql.sql import SQLDatabaseChain
from sql_chain.models.model import Queries
from sql_chain.utils.log_setup import setup_logger

logger = setup_logger(__name__)


async def execute_query(state: Dict[str, Any]) -> Dict[str, Any]:
    result_state = {**state}
    logger.info("Executing SQL query")
    try:
        # Use provided database if available, otherwise create new one
        database = SQLDatabaseChain()

        # Handle both single query and multiple queries cases
        if "sql_queries" in state:
            # Multiple queries case
            queries: Queries = state["sql_queries"]
            results = []
            for query in queries.queries:
                result = await database.run_query(query.query)
                results.append(result)
            result_state["results"] = results
            # save to json file
            try:
                with open("sql_results.json", "w") as f:
                    # Convert Pydantic models to dictionaries using model_dump()
                    res = [r.model_dump() for r in results]
                    # Use json.dump for proper JSON formatting
                    json.dump(res, f, indent=2)
            except IOError as e:
                logger.error(f"Error writing to file: {e}")
            return result_state
        else:
            raise ValueError("No query provided in state")

    except Exception as e:
        logger.error(f"Error executing query: {e}")
        raise

    return result_state
