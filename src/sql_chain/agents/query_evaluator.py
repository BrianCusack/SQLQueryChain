from typing import Dict, Any

from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import PydanticOutputParser

from sql_chain.models.model import QueryEvaluation
from langchain_community.utilities.sql_database import SQLDatabase
from sql_chain.config import Settings
from sql_chain.utils.log_setup import setup_logger

logger = setup_logger(__name__)
settings = Settings()


async def execute_query(state: Dict[str, Any]) -> Dict[str, Any]:
    result_state = {**state}
    logger.info("Evaluting query results")

    # Extract previous query results
    query_results = result_state.get("results", {})
    schema = result_state.get("schema", "")

    # Initialize the database chain
    db_chain = SQLDatabase.from_uri(settings.DATABASE_URL)

    # Set up the LLM for generating validation queries
    llm = ChatGoogleGenerativeAI(
        model=settings.GEMINI_MODEL, temperature=0.2, api_key=settings.GOOGLE_API_KEY
    )

    # Create prompt for generating validation queries
    validation_prompt = ChatPromptTemplate.from_template("""
    You are a postgresql database expert tasked with validating SQL query results.
    
    Queries to evaluate: {query_results}
    
    Database schema information: {schema}
    
    Generate 1-3 simple SQL validation queries that can verify the accuracy of the original results.
    Focus on simply verifying key metrics, counts, or sample data points from the original results.
    Use and attach the the comments from the original query to guide your validation.
    Return only the SQL queries, one per line.
    """)

    # Generate validation queries
    validation_chain = validation_prompt | llm
    validation_response = await validation_chain.ainvoke(
        {"query_results": query_results, "table_info": schema}
    )

    # Extract validation queries from the response
    validation_queries = [
        q.strip()
        for q in validation_response.content.split("\n")
        if q.strip().startswith("SELECT")
    ]
    logger.info(f"Generated {len(validation_queries)} validation queries")

    # Execute validation queries
    validation_results = {}
    for i, query in enumerate(validation_queries):
        try:
            result = await db_chain.run(query)
            validation_results[f"validation_{i + 1}"] = result
            logger.info(f"Executed validation query {i + 1}")
        except Exception as e:
            logger.error(f"Error executing validation query: {e}")
            validation_results[f"validation_{i + 1}_error"] = str(e)

    # Create prompt for evaluating results
    evaluation_prompt = ChatPromptTemplate.from_template("""
    You are a postgresql database expert tasked with evaluating query results.
    
    Original query: {original_query}
    
    Original results: {original_results}
    
    Validation queries and results:
    {validation_results}
    
    Based on the validation queries and their results, evaluate the original query results.
    Provide:
    1. A score between 0.0 (completely incorrect) and 1.0 (perfectly accurate)
    2. A detailed comment explaining your evaluation
    
    Respond in the following JSON format:
    ```
    {{"score": float, "comment": "string", "validation_queries": [list_of_queries]}}
    ```
    """)

    # Set up output parser
    parser = PydanticOutputParser(pydantic_object=QueryEvaluation)

    # Generate evaluation
    evaluation_chain = evaluation_prompt | llm | parser
    evaluation = await evaluation_chain.ainvoke(
        {"original_results": query_results, "validation_results": validation_results}
    )

    # Update state with evaluation results
    result_state["query_evaluation"] = {
        "score": evaluation.score,
        "comment": evaluation.comment,
        "validation_queries": evaluation.validation_queries,
        "validation_results": validation_results,
    }

    logger.info(f"Query evaluation complete. Score: {evaluation.score}")
    return result_state
