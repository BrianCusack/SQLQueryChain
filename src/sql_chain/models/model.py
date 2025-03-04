from pydantic import BaseModel
from typing import TypedDict


class Query(BaseModel):
    query: str


class Queries(BaseModel):
    queries: list[Query]


class GraphState(TypedDict):
    questions: list[str]
    sql_queries: Queries
    results: list[dict]
    schema: str


class QueryResult(BaseModel):
    success: bool
    query: str
    data: dict
    error: str = None
