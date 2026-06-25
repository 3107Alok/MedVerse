from pymongo import MongoClient
import os
from dotenv import load_dotenv

load_dotenv()

def get_db():
    mongo_uri = os.getenv("MONGO_URI")
    if not mongo_uri:
        raise ValueError("MONGO_URI not found in environment variables")
    
    client = MongoClient(mongo_uri)
    db = client.get_database("medinexa_db")
    return db
