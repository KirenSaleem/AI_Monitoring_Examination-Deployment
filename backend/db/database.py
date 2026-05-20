import os
import certifi

from pymongo import MongoClient
from pymongo.collection import Collection
from pymongo.database import Database

MONGO_URL = os.getenv("MONGO_URL")

DB_NAME = "examguard_db"
TEACHERS_COLLECTION = "teachers"
CLASSROOMS_COLLECTION = "classrooms"
STUDENTS_COLLECTION = "students"
EXAM_SESSIONS_COLLECTION = "exam_sessions"
NOTIFICATIONS_COLLECTION = "notifications"

try:
    client = MongoClient(
        MONGO_URL,
        tls=True,
        tlsCAFile=certifi.where()
    )

    client.server_info()
    print("MongoDB connected successfully")

    database: Database = client[DB_NAME]

    teachers_collection: Collection = database[TEACHERS_COLLECTION]
    classrooms_collection: Collection = database[CLASSROOMS_COLLECTION]
    students_collection: Collection = database[STUDENTS_COLLECTION]
    exam_sessions_collection: Collection = database[EXAM_SESSIONS_COLLECTION]
    notifications_collection: Collection = database[NOTIFICATIONS_COLLECTION]

    existing_collections = database.list_collection_names()

    if NOTIFICATIONS_COLLECTION not in existing_collections:
        database.create_collection(NOTIFICATIONS_COLLECTION)
        print("MongoDB notifications collection created")

    if STUDENTS_COLLECTION not in existing_collections:
        database.create_collection(STUDENTS_COLLECTION)
        print("MongoDB students collection created")

except Exception as e:
    print("MongoDB connection error:", e)