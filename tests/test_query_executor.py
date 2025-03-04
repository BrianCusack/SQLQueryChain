import pytest


class MockDatabase:
    def __init__(self, return_value=None, should_raise=False):
        self.return_value = return_value or [{"id": 1, "name": "test"}]
        self.should_raise = should_raise

    def run(self, query: str):
        if self.should_raise:
            raise Exception("Database error")
        return self.return_value


class TestQueryExecutor:
    @pytest.fixture
    async def query_executor(self):
        from sql_chain.agents.query_executor import execute_query

        return execute_query

    @pytest.mark.asyncio
    async def test_successful_query(self, query_executor):
        # Arrange
        mock_data = [{"id": 1, "name": "test"}]
        mock_db = MockDatabase(return_value=mock_data)

        # Act
        result = await query_executor({"db": mock_db, "query": "SELECT * FROM test"})

        # Assert
        assert result["success"] is True
        assert result["data"] == mock_data
        assert result["query"] == "SELECT * FROM test"

    @pytest.mark.asyncio
    async def test_failed_query(self, query_executor):
        # Arrange
        mock_db = MockDatabase(should_raise=True)

        # Act
        result = await query_executor({"db": mock_db, "query": "SELECT * FROM test"})

        # Assert
        assert result["success"] is False
        assert "Database error" in result["error"]

    @pytest.mark.asyncio
    async def test_empty_query(self, query_executor):
        # Arrange
        mock_db = MockDatabase()

        # Act
        result = await query_executor({"db": mock_db, "query": ""})

        # Assert
        assert result["success"] is False
        assert "empty query" in result["error"].lower()
