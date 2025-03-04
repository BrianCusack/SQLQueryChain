from typing import Dict, Any

from langchain_google_genai import ChatGoogleGenerativeAI
from sql_chain.sql.sql import SQLDatabaseChain
from langchain_core.messages import HumanMessage
from sql_chain.utils.log_setup import setup_logger
from sql_chain.config import Settings

settings = Settings()

logger = setup_logger(__name__)


def question_agent(state: Dict[str, Any]) -> Dict[str, Any]:
    """
    Commentor agent for dynamically adding descriptive column comments to a database
    1. get the tables schema
    3. generate n natural language questions
    """
    return_state = {**state}
    logger.info("Generating questions")
    try:
        llm = ChatGoogleGenerativeAI(
            model=settings.GEMINI_MODEL, temperature=0, api_key=settings.GOOGLE_API_KEY
        )
        database = SQLDatabaseChain()
        schema = database.get_schema()
        return_state["schema"] = schema
        prompt = f"""Based on the schema: {schema} provided, generate three complex analytical questions that would be valuable for a banking analysis.
        Format each question on a new line. Focus on relationships between customers, accounts, and transactions.
        """
        response = llm.invoke([HumanMessage(content=prompt)])
        questions = [q.strip() for q in response.content.split("\n") if q.strip()]
        return_state["questions"] = questions
        with open("questions.txt", "w") as f:
            for q in questions:
                f.write(q + "\n")
        logger.info("Questions generated successfully")
    except Exception as e:
        logger.error(f"Error in commentor agent: {e}")
    return return_state
