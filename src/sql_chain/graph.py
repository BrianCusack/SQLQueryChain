from langgraph.graph import Graph, END
from sql_chain.agents import question_generator, sql_formulator, query_executor
from sql_chain.models.model import GraphState
from sql_chain.utils.log_setup import setup_logger
import asyncio

logger = setup_logger(__name__)


async def execute_query_async(state: GraphState) -> GraphState:
    return await query_executor.execute_query(state)


def execute_query(state: GraphState) -> GraphState:
    """Synchronous wrapper for async execute_query"""
    return asyncio.run(execute_query_async(state))


def create_graph():
    def generate_questions(state: GraphState) -> GraphState:
        return question_generator.question_agent(state)

    def formulate_sql(state: GraphState) -> GraphState:
        return sql_formulator.formulate_sql(state)

    # Build workflow
    workflow = Graph()

    # Add nodes
    workflow.add_node("generate_questions", generate_questions)
    workflow.add_node("formulate_sql", formulate_sql)
    workflow.add_node("execute_query", execute_query)

    # Set entry point
    workflow.set_entry_point("generate_questions")
    workflow.add_edge("generate_questions", "formulate_sql")
    workflow.add_edge("formulate_sql", "execute_query")
    workflow.add_edge("execute_query", END)

    # Compile
    return workflow.compile()


def run_workflow():
    graph = create_graph()

    # Initialize state
    initial_state = GraphState(schema="", questions=[], sql_queries=None, results=[])

    # Run workflow
    final_state = graph.invoke(initial_state)
    return final_state


if __name__ == "__main__":
    run_workflow()
