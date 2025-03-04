from langchain_community.utilities.sql_database import SQLDatabase
from typing import Dict, Any
from sql_chain.models.model import QueryResult
from sql_chain.config import Settings

settings = Settings()


class SQLDatabaseChain:
    def __init__(self):
        self.db = SQLDatabase.from_uri(settings.DATABASE_URL)

    def get_schema(self) -> str:
        """Get the database schema"""
        return self.db.get_table_info()

    async def run_query(self, query: str) -> Dict[str, Any]:
        """Execute a SQL query against the database"""
        try:
            # Execute the query without await since it's synchronous
            result = self.db.run(query)
            if result == "" or len(result) == 0:
                return QueryResult(
                    success=True, query=query, data={}, error="No data returned"
                )

            # Ensure result is a dictionary
            if isinstance(result, list):
                data = {"results": result}
            elif not isinstance(result, dict):
                data = {"value": result}
            else:
                data = result

            return QueryResult(success=True, query=query, data=data)
        except Exception as e:
            return QueryResult(success=False, query=query, data={}, error=str(e))
