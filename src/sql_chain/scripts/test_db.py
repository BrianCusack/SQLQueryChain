import asyncio
from dotenv import load_dotenv
from sql_chain.sql.sql import SQLDatabaseChain


async def test_database():
    # Initialize database connection
    db = SQLDatabaseChain()

    # Simple test query
    test_query = "SELECT current_timestamp;"

    print("Executing test query...")
    result = await db.run_query(test_query)

    if result["success"]:
        print("Query successful!")
        print("Results:", result["data"])
    else:
        print("Query failed!")
        print("Error:", result["error"])


def main():
    load_dotenv()
    asyncio.run(test_database())


if __name__ == "__main__":
    main()
