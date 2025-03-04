from typing import Dict, Any

from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import ChatPromptTemplate
from sql_chain.models.model import Queries
from sql_chain.utils.log_setup import setup_logger
from sql_chain.config import Settings

settings = Settings()

logger = setup_logger(__name__)


def formulate_sql(state: Dict[str, Any]) -> Dict[str, Any]:
    return_state = {**state}
    logger.info("Formulating SQL queries")
    try:
        llm = ChatGoogleGenerativeAI(
            model=settings.GEMINI_MODEL,
            temperature=0,
            api_key=settings.GOOGLE_API_KEY,
        )
        structured_llm = llm.with_structured_output(Queries)

        prompt = ChatPromptTemplate.from_template("""
        Given the following PostgreSQL database schema:
        {schema}
        
        Formulate SQL queries to answer these questions:
        {questions}
        
        Add the questions as comments in the SQL queries.

        """)
        chain = prompt | structured_llm
        questions = state["questions"]
        result: Queries = chain.invoke(
            {"schema": state["schema"], "questions": questions}
        )
        try:
            with open("sql_queries.txt", "w") as f:
                for q in result.queries:
                    f.write(q.query + "\n")
        except IOError as e:
            logger.error(f"Error writing to file: {e}")

        return_state["sql_queries"] = result
        logger.info("SQL queries generated successfully for the questions")
        return return_state
    except Exception as e:
        logger.error(f"Error in SQL formulator agent: {e}")

    return return_state
