import os
from langchain_community.utilities.sql_database import SQLDatabase
from sql_chain.config import Settings

settings = Settings()


def init_database():
    """Initialize the banking database using langchain SQLDatabase."""
    try:
        # Initialize SQLDatabase with postgres connection
        db = SQLDatabase.from_uri(
            settings.DATABASE_URL.replace(settings.DB_NAME, "postgres")
        )

        # Create database if it doesn't exist
        create_db_query = f"""
        SELECT 'CREATE DATABASE {settings.DB_NAME}'
        WHERE NOT EXISTS (
            SELECT FROM pg_database WHERE datname = '{settings.DB_NAME}'
        );
        """
        db.run(create_db_query)

        # Connect to the new database
        db = SQLDatabase.from_uri(settings.DATABASE_URL)

        # Read and execute the SQL script
        script_path = os.path.join(
            os.path.dirname(__file__), "bank-database-script.sql"
        )
        with open(script_path, "r") as sql_file:
            sql_script = sql_file.read()

        # Execute the initialization script
        db.run(sql_script)
        print(f"Successfully initialized {settings.DB_NAME}")

    except Exception as e:
        print(f"Error initializing database: {str(e)}")
        raise


if __name__ == "__main__":
    init_database()
