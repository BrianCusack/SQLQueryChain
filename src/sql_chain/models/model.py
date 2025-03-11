from pydantic import BaseModel, Field
from typing import TypedDict, List


class Query(BaseModel):
    query: str


class Queries(BaseModel):
    queries: list[Query]

class QueryResult(BaseModel):
    success: bool
    query: str
    data: dict
    error: str = None    

class QueryEvaluation(BaseModel):
    score: float = Field(description="Evaluation score from 0.0 to 1.0")
    comment: str = Field(description="Detailed comment explaining the evaluation")
    validation_queries: List[str] = Field(description="Queries used for validation")

class GraphState(TypedDict):
    questions: list[str]
    sql_queries: Queries
    results: list[dict]
    evaluations: list[QueryEvaluation]
    schema: str



