from dataclasses import dataclass
import psycopg2
from faker import Faker
from langchain_core.messages import HumanMessage
from sql_chain.sql.sql import SQLDatabaseChain
import json


@dataclass
class DatabaseTools:
    conn: psycopg2.extensions.connection
    faker: Faker
    sql_chain: SQLDatabaseChain

    @classmethod
    def from_config(cls, config: dict):
        conn = psycopg2.connect(**config)
        db_url = f"postgresql://{config['user']}:{config['password']}@{config['host']}:{config['port']}/{config['database']}"
        return cls(conn=conn, faker=Faker(), sql_chain=SQLDatabaseChain(db_url))

    def _get_fake_data_instructions(self) -> dict:
        prompt = """Given a banking database with customers, accounts, and transactions tables, 
        provide realistic data generation rules for each table. Return a JSON structure with:
        - Value ranges for numeric fields
        - Patterns for names, emails, addresses
        - Distribution of account types
        - Transaction types and amount ranges
        Focus on creating realistic banking data patterns."""

        response = self.llm.invoke([HumanMessage(content=prompt)])
        return json.loads(response.content)

    def populate_data(self) -> str:
        try:
            with self.conn.cursor() as cur:
                # Check if tables are empty
                cur.execute("""
                    SELECT table_name 
                    FROM information_schema.tables 
                    WHERE table_schema = 'public'
                """)
                tables = cur.fetchall()

                for table in tables:
                    cur.execute(f"SELECT COUNT(*) FROM {table[0]}")
                    count = cur.fetchone()[0]
                    if count == 0:
                        if table[0] == "customers":
                            self._populate_customers(cur)
                        elif table[0] == "accounts":
                            self._populate_accounts(cur)
                        elif table[0] == "transactions":
                            self._populate_transactions(cur)

                self.conn.commit()
                return "Database populated successfully"
        except Exception as e:
            self.conn.rollback()
            return f"Error populating database: {str(e)}"

    def _populate_customers(self, cur):
        for _ in range(100):
            name = self.faker.name()
            email = f"{name.lower().replace(' ', '.')}@{self.faker.domain_name()}"
            cur.execute(
                """
                INSERT INTO customers (name, email, address)
                VALUES (%s, %s, %s)
            """,
                (name, email, self.faker.address()),
            )

    def _populate_accounts(self, cur):
        rules = self._get_fake_data_instructions()
        cur.execute("SELECT id FROM customers")
        customer_ids = cur.fetchall()
        for cid in customer_ids:
            account_type = self.faker.random_element(
                rules.get("account_types", ["checking", "savings"])
            )
            balance = self.faker.random_number(digits=rules.get("balance_digits", 5))
            cur.execute(
                """
                INSERT INTO accounts (customer_id, account_type, balance)
                VALUES (%s, %s, %s)
            """,
                (cid[0], account_type, balance),
            )

    def _populate_transactions(self, cur):
        # This method needs to be implemented
        pass

    def _get_table_comments(self) -> dict:
        prompt = """For a banking database with customers, accounts, and transactions tables,
        provide detailed column comments that explain:
        - The business purpose of each column
        - Any constraints or expected values
        - Relationships between tables
        Return the comments in a structured JSON format."""

        response = self.llm.invoke([HumanMessage(content=prompt)])
        return json.loads(response.content)

    def add_comments(self) -> str:
        try:
            comments = self._get_table_comments()
            with self.conn.cursor() as cur:
                for table, columns in comments.items():
                    for column, comment in columns.items():
                        cur.execute(
                            f"""
                            COMMENT ON COLUMN {table}.{column} IS %s
                        """,
                            (comment,),
                        )

                self.conn.commit()
                return "Comments added successfully"
        except Exception as e:
            self.conn.rollback()
            return f"Error adding comments: {str(e)}"

    def execute_query(self, query: str) -> dict:
        return self.sql_chain.run_query(query)
