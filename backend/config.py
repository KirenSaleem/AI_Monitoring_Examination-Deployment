from pathlib import Path

import firebase_admin
from firebase_admin import credentials

# Build an absolute path to the Firebase service account file.
SERVICE_ACCOUNT_PATH = Path(__file__).resolve().parent / "serviceAccountKey.json"


def get_firebase_app() -> firebase_admin.App:
    """
    Return the Firebase app instance.
    Initializes Firebase only once (singleton-like behavior).
    """
    if not firebase_admin._apps:
        cred = credentials.Certificate(str(SERVICE_ACCOUNT_PATH))
        firebase_admin.initialize_app(cred)
        print("Firebase app initialized")
    else:
        print("Firebase app already initialized")

    return firebase_admin.get_app()


# Import this variable anywhere Firebase app access is needed.
firebase_app = get_firebase_app()
