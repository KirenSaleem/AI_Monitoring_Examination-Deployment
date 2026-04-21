from firebase_admin import auth

from config import firebase_app


def verify_firebase_token(token: str) -> dict:
    """
    Verify a Firebase ID token and return basic user info.
    """
    if not token:
        raise ValueError("Token is required.")

    try:
        decoded_token = auth.verify_id_token(token, app=firebase_app)

        return {
            "uid": decoded_token.get("uid"),
            "email": decoded_token.get("email"),
        }
    except (auth.InvalidIdTokenError, auth.ExpiredIdTokenError, auth.RevokedIdTokenError) as exc:
        raise ValueError("Invalid or expired Firebase token.") from exc
    except Exception as exc:
        raise ValueError("Token verification failed.") from exc
