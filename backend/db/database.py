from pymongo import MongoClient
from pymongo.collection import Collection
from pymongo.database import Database

MONGO_URL = "mongodb://localhost:27017"
DB_NAME = "examguard_db"
USERS_COLLECTION = "users"
CLASSROOMS_COLLECTION = "classrooms"
EXAM_SESSIONS_COLLECTION = "exam_sessions"
NOTIFICATIONS_COLLECTION = "notifications"

try:
    client = MongoClient(MONGO_URL)
    client.server_info()
    print("MongoDB connected successfully")

    database: Database = client[DB_NAME]
    users_collection: Collection = database[USERS_COLLECTION]
    classrooms_collection: Collection = database[CLASSROOMS_COLLECTION]
    exam_sessions_collection: Collection = database[EXAM_SESSIONS_COLLECTION]
    notifications_collection: Collection = database[NOTIFICATIONS_COLLECTION]

    existing_collections = database.list_collection_names()
    if NOTIFICATIONS_COLLECTION not in existing_collections:
        database.create_collection(NOTIFICATIONS_COLLECTION)
        print("MongoDB notifications collection created")

except Exception as e:
    print("MongoDB connection error:", e)