from db import get_db

db = get_db()
users_collection = db.users

class UserModel:
    @staticmethod
    def create_user(user_data):
        return users_collection.insert_one(user_data)

    @staticmethod
    def get_user_by_uid(uid):
        return users_collection.find_one({"uid": uid}, {"_id": 0})

    @staticmethod
    def update_user_status(uid, status):
        return users_collection.update_one({"uid": uid}, {"$set": {"status": status}})

    @staticmethod
    def get_pending_doctors():
        return list(users_collection.find({"role": "doctor", "status": "Pending"}, {"_id": 0}))
